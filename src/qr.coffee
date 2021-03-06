QR =
  init: ->
    return if g.VIEW is 'catalog' or !Conf['Quick Reply']

    Misc.clearThreads "yourPosts.#{g.BOARD}"
    @syncYourPosts()

    if Conf['Hide Original Post Form']
      $.addClass doc, 'hide-original-post-form'

    $.on d, '4chanXInitFinished', @initReady

    Post::callbacks.push
      name: 'Quick Reply'
      cb:   @node

  initReady: ->
    QR.postingIsEnabled = !!$.id 'postForm'
    return unless QR.postingIsEnabled

    sc = $.el 'a',
      className: 'qr-shortcut'
      textContent: 'QR'
      title: 'Quick Reply'
      href: 'javascript:;'
    $.on sc, 'click', ->
      $.event 'CloseMenu'
      QR.open()
      QR.resetThreadSelector()
      QR.nodes.com.focus()
    Header.addShortcut sc

    if $.engine is 'webkit'
      $.on d, 'paste',            QR.paste
    $.on d, 'dragover',           QR.dragOver
    $.on d, 'drop',               QR.dropFile
    $.on d, 'dragstart dragend',  QR.drag
    $.on d, 'ThreadUpdate', ->
      if g.DEAD
        QR.abort()
      else
        QR.status()

    QR.persist() if Conf['Persistent QR']

  node: ->
    $.on $('a[title="Quote this post"]', @nodes.info), 'click', QR.quote

  persist: ->
    QR.open()
    QR.hide() if Conf['Auto-Hide QR']
  open: ->
    if QR.nodes
      QR.nodes.el.hidden = false
      QR.unhide()
      return
    try
      QR.dialog()
    catch err
      delete QR.nodes
      Main.handleErrors
        message: 'Quick Reply dialog creation crashed.'
        error: err
  close: ->
    if QR.req
      QR.abort()
      return
    QR.nodes.el.hidden = true
    QR.cleanNotifications()
    d.activeElement.blur()
    $.rmClass QR.nodes.el, 'dump'
    for i in QR.posts
      QR.posts[0].rm()
    QR.cooldown.auto = false
    QR.status()
    if !Conf['Remember Spoiler'] and QR.nodes.spoiler.checked
      QR.nodes.spoiler.click()
  hide: ->
    d.activeElement.blur()
    $.addClass QR.nodes.el, 'autohide'
    QR.nodes.autohide.checked = true
  unhide: ->
    $.rmClass QR.nodes.el, 'autohide'
    QR.nodes.autohide.checked = false
  toggleHide: ->
    if @checked
      QR.hide()
    else
      QR.unhide()

  syncYourPosts: (yourPosts) ->
    if yourPosts
      QR.yourPosts = yourPosts
      return
    QR.yourPosts = $.get "yourPosts.#{g.BOARD}", threads: {}
    $.sync "yourPosts.#{g.BOARD}", QR.syncYourPosts

  error: (err) ->
    QR.open()
    if typeof err is 'string'
      el = $.tn err
    else
      el = err
      el.removeAttribute 'style'
    if QR.captcha.isEnabled and /captcha|verification/i.test el.textContent
      # Focus the captcha input on captcha error.
      QR.captcha.nodes.input.focus()
    alert el.textContent if d.hidden
    QR.notifications.push new Notification 'warning', el
  notifications: []
  cleanNotifications: ->
    for notification in QR.notifications
      notification.close()
    QR.notifications = []

  status: ->
    return unless QR.nodes
    if g.DEAD
      value    = 404
      disabled = true
      QR.cooldown.auto = false

    value = if QR.req
      QR.req.progress
    else
      QR.cooldown.seconds or value

    {status} = QR.nodes
    status.value = unless value
      'Submit'
    else if QR.cooldown.auto
      "Auto #{value}"
    else
      value
    status.disabled = disabled or false

  cooldown:
    init: ->
      board = g.BOARD.ID
      QR.cooldown.types =
        thread: switch board
          when 'q' then 86400
          when 'b', 'soc', 'r9k' then 600
          else 300
        sage: if board is 'q' then 600 else 60
        file: if board is 'q' then 300 else 30
        post: if board is 'q' then 60  else 30
      QR.cooldown.cooldowns = $.get "cooldown.#{board}", {}
      QR.cooldown.upSpd = 0
      QR.cooldown.upSpdAccuracy = .5
      QR.cooldown.start()
      $.sync "cooldown.#{board}", QR.cooldown.sync
    start: ->
      return if QR.cooldown.isCounting
      QR.cooldown.isCounting = true
      QR.cooldown.count()
    sync: (cooldowns) ->
      # Add each cooldowns, don't overwrite everything in case we
      # still need to prune one in the current tab to auto-post.
      for id of cooldowns
        QR.cooldown.cooldowns[id] = cooldowns[id]
      QR.cooldown.start()
    set: (data) ->
      {req, post, isReply, delay} = data
      start = if req then req.uploadEndTime else Date.now()
      if delay
        cooldown = {delay}
      else
        if post.file
          upSpd = post.file.size / ((req.uploadEndTime - req.uploadStartTime) / $.SECOND)
          QR.cooldown.upSpdAccuracy = ((upSpd > QR.cooldown.upSpd * .9) + QR.cooldown.upSpdAccuracy) / 2
          QR.cooldown.upSpd = upSpd
        isSage  = /sage/i.test post.email
        hasFile = !!post.file
        type = unless isReply
          'thread'
        else if isSage
          'sage'
        else if hasFile
          'file'
        else
          'post'
        cooldown =
          isReply: isReply
          isSage:  isSage
          hasFile: hasFile
          timeout: start + QR.cooldown.types[type] * $.SECOND
      QR.cooldown.cooldowns[start] = cooldown
      $.set "cooldown.#{g.BOARD}", QR.cooldown.cooldowns
      QR.cooldown.start()
    unset: (id) ->
      delete QR.cooldown.cooldowns[id]
      if Object.keys(QR.cooldown.cooldowns).length
        $.set "cooldown.#{g.BOARD}", QR.cooldown.cooldowns
      else
        $.delete "cooldown.#{g.BOARD}"
    count: ->
      unless Object.keys(QR.cooldown.cooldowns).length
        $.delete "#{g.BOARD}.cooldown"
        delete QR.cooldown.isCounting
        delete QR.cooldown.seconds
        QR.status()
        return

      setTimeout QR.cooldown.count, $.SECOND

      now     = Date.now()
      post    = QR.posts[0]
      isReply = QR.nodes.thread.value isnt 'new'
      isSage  = /sage/i.test post.email
      hasFile = !!post.file
      seconds = null
      {types, cooldowns, upSpd, upSpdAccuracy} = QR.cooldown

      for start, cooldown of cooldowns
        if 'delay' of cooldown
          if cooldown.delay
            seconds = Math.max seconds, cooldown.delay--
          else
            seconds = Math.max seconds, 0
            QR.cooldown.unset start
          continue

        if isReply is cooldown.isReply
          # Only cooldowns relevant to this post can set the seconds value.
          # Unset outdated cooldowns that can no longer impact us.
          type = unless isReply
            'thread'
          else if isSage and cooldown.isSage
            'sage'
          else if hasFile and cooldown.hasFile
            'file'
          else
            'post'
          elapsed = Math.floor (now - start) / $.SECOND
          if elapsed >= 0 # clock changed since then?
            seconds = Math.max seconds, types[type] - elapsed
            if hasFile and upSpd
              seconds -= Math.floor post.file.size / upSpd * upSpdAccuracy
              seconds  = Math.max seconds, 0
        unless start <= now <= cooldown.timeout
          QR.cooldown.unset start

      # Update the status when we change posting type.
      # Don't get stuck at some random number.
      # Don't interfere with progress status updates.
      update = seconds isnt null or !!QR.cooldown.seconds
      QR.cooldown.seconds = seconds
      QR.status() if update
      QR.submit() if seconds is 0 and QR.cooldown.auto and !QR.req

  quote: (e) ->
    e?.preventDefault()
    return unless QR.postingIsEnabled

    sel = d.getSelection()
    selectionRoot = $.x 'ancestor::div[contains(@class,"postContainer")][1]', sel.anchorNode
    post = Get.postFromNode @
    {OP} = Get.contextFromLink(@).thread

    text = ">>#{post}\n"
    if (s = sel.toString().trim()) and post.nodes.root is selectionRoot
      # XXX Opera doesn't retain `\n`s?
      s = s.replace /\n/g, '\n>'
      text += ">#{s}\n"

    QR.open()
    ta = QR.nodes.com
    QR.nodes.thread.value = OP.ID unless ta.value

    caretPos = ta.selectionStart
    # Replace selection for text.
    ta.value = ta.value[...caretPos] + text + ta.value[ta.selectionEnd..]
    # Move the caret to the end of the new quote.
    range = caretPos + text.length
    ta.setSelectionRange range, range
    ta.focus()

    # Fire the 'input' event
    $.event 'input', null, ta

  characterCount: ->
    counter = QR.nodes.charCount
    count   = QR.nodes.com.textLength
    counter.textContent = count
    counter.hidden      = count < 1000
    (if count > 1500 then $.addClass else $.rmClass) counter, 'warning'

  drag: (e) ->
    # Let it drag anything from the page.
    toggle = if e.type is 'dragstart' then $.off else $.on
    toggle d, 'dragover', QR.dragOver
    toggle d, 'drop',     QR.dropFile
  dragOver: (e) ->
    e.preventDefault()
    e.dataTransfer.dropEffect = 'copy' # cursor feedback
  dropFile: (e) ->
    # Let it only handle files from the desktop.
    return unless e.dataTransfer.files.length
    e.preventDefault()
    QR.open()
    QR.fileInput e.dataTransfer.files
    $.addClass QR.nodes.el, 'dump'
  paste: (e) ->
    files = []
    for item in e.clipboardData.items
      if item.kind is 'file'
        blob = item.getAsFile()
        blob.name  = 'file'
        blob.name += '.' + blob.type.split('/')[1] if blob.type
        files.push blob
    return unless files.length
    QR.open()
    QR.fileInput files
  openFileInput: ->
    QR.nodes.fileInput.click()
  fileInput: (files) ->
    if @ instanceof Element #or files instanceof Event # file input
      files = [@files...]
      QR.nodes.fileInput.value = null # Don't hold the files from being modified on windows
    {length} = files
    return unless length
    max = QR.nodes.fileInput.max
    QR.cleanNotifications()
    # Set or change current post's file.
    if length is 1
      file = files[0]
      if /^text/.test file.type
        QR.selected.pasteText file
      else if file.size > max
        QR.error "File too large (file: #{$.bytesToString file.size}, max: #{$.bytesToString max})."
      else unless file.type in QR.mimeTypes
        QR.error 'Unsupported file type.'
      else
        QR.selected.setFile file
      return
    # Create new posts with these files.
    for file in files
      if /^text/.test file.type
        if (post = QR.posts[QR.posts.length - 1]).com
          post = new QR.post()
        post.pasteText file
      else if file.size > max
        QR.error "#{file.name}: File too large (file: #{$.bytesToString file.size}, max: #{$.bytesToString max})."
      else unless file.type in QR.mimeTypes
        QR.error "#{file.name}: Unsupported file type."
      else
        if (post = QR.posts[QR.posts.length - 1]).file
          post = new QR.post()
        post.setFile file
    $.addClass QR.nodes.el, 'dump'
  resetThreadSelector: ->
    if g.VIEW is 'thread'
      QR.nodes.thread.value = g.THREAD
    else
      QR.nodes.thread.value = 'new'

  posts: []
  post: class
    constructor: ->
      # set values, or null, to avoid 'undefined' values in inputs
      prev     = QR.posts[QR.posts.length - 1]
      persona  = $.get 'QR.persona', {}
      @name    = if prev then prev.name else persona.name or null
      @email   = if prev and !/^sage$/.test prev.email then prev.email   else persona.email or null
      @sub     = if prev and Conf['Remember Subject']  then prev.sub     else if Conf['Remember Subject'] then persona.sub else null
      @spoiler = if prev and Conf['Remember Spoiler']  then prev.spoiler else false
      @com = null

      el = $.el 'a',
        className: 'qr-preview'
        draggable: true
        href: 'javascript:;'
        innerHTML: '<a class=remove>×</a><label hidden><input type=checkbox> Spoiler</label><span></span>'

      @nodes =
        el:      el
        rm:      el.firstChild
        label:   $ 'label', el
        spoiler: $ 'input', el
        span:    el.lastChild

      @nodes.spoiler.checked = @spoiler

      $.on el,             'click',  @select.bind @
      $.on @nodes.rm,      'click',  (e) => e.stopPropagation(); @rm()
      $.on @nodes.label,   'click',  (e) => e.stopPropagation()
      $.on @nodes.spoiler, 'change', (e) =>
        @spoiler = e.target.checked
        QR.nodes.spoiler.checked = @spoiler if @ is QR.selected
      $.add QR.nodes.dumpList, el

      for event in ['dragStart', 'dragEnter', 'dragLeave', 'dragOver', 'dragEnd', 'drop']
        $.on el, event.toLowerCase(), @[event]

      @unlock()
      QR.posts.push @
    rm: ->
      $.rm @nodes.el
      index = QR.posts.indexOf @
      if QR.posts.length is 1
        new QR.post().select()
      else if @ is QR.selected
        (QR.posts[index-1] or QR.posts[index+1]).select()
      QR.posts.splice index, 1
      return unless window.URL
      URL.revokeObjectURL @URL
    lock: (lock=true) ->
      @isLocked = lock
      return unless @ is QR.selected
      for name in ['name', 'email', 'sub', 'com', 'fileButton', 'spoiler']
        QR.nodes[name].disabled = lock
      @nodes.rm.style.visibility =
        QR.nodes.fileRM.style.visibility = if lock then 'hidden' else ''
      (if lock then $.off else $.on) QR.nodes.filename.parentNode, 'click', QR.openFileInput
      @nodes.spoiler.disabled = lock
      @nodes.el.draggable = !lock
    unlock: ->
      @lock false
    select: ->
      if QR.selected
        QR.selected.nodes.el.id = null
        QR.selected.forceSave()
      QR.selected = @
      @lock @isLocked
      @nodes.el.id = 'selected'
      # Scroll the list to center the focused post.
      rectEl   = @nodes.el.getBoundingClientRect()
      rectList = @nodes.el.parentNode.getBoundingClientRect()
      @nodes.el.parentNode.scrollLeft += rectEl.left + rectEl.width/2 - rectList.left - rectList.width/2
      # Load this post's values.
      for name in ['name', 'email', 'sub', 'com']
        QR.nodes[name].value = @[name]
      @showFileData()
      QR.characterCount()
    save: (input) ->
      {value} = input
      @[input.dataset.name] = value
      return if input.nodeName isnt 'TEXTAREA'
      @nodes.span.textContent = value
      QR.characterCount()
      # Disable auto-posting if you're typing in the first post
      # during the last 5 seconds of the cooldown.
      if QR.cooldown.auto and @ is QR.posts[0] and 0 < QR.cooldown.seconds <= 5
        QR.cooldown.auto = false
    forceSave: ->
      return unless @ is QR.selected
      # Do this in case people use extensions
      # that do not trigger the `input` event.
      for name in ['name', 'email', 'sub', 'com']
        @save QR.nodes[name]
      return
    setFile: (@file) ->
      @filename           = "#{file.name} (#{$.bytesToString file.size})"
      @nodes.el.title     = @filename
      @nodes.label.hidden = false if QR.spoiler
      URL.revokeObjectURL @URL if window.URL
      @showFileData()
      unless /^image/.test file.type
        @nodes.el.style.backgroundImage = null
        return
      @setThumbnail()
    setThumbnail: (fileURL) ->
      # XXX Opera does not support blob URL
      # Create a redimensioned thumbnail.
      unless window.URL
        unless fileURL
          reader = new FileReader()
          reader.onload = (e) =>
            @setThumbnail e.target.result
          reader.readAsDataURL @file
          return
      else
        fileURL = URL.createObjectURL @file

      img = $.el 'img'

      img.onload = =>
        # Generate thumbnails only if they're really big.
        # Resized pictures through canvases look like ass,
        # so we generate thumbnails `s` times bigger then expected
        # to avoid crappy resized quality.
        s = 90*2
        {height, width} = img
        if height < s or width < s
          @URL = fileURL if window.URL
          @nodes.el.style.backgroundImage = "url(#{@URL})"
          return
        if height <= width
          width  = s / height * width
          height = s
        else
          height = s / width  * height
          width  = s
        cv = $.el 'canvas'
        cv.height = img.height = height
        cv.width  = img.width  = width
        cv.getContext('2d').drawImage img, 0, 0, width, height
        unless window.URL
          @nodes.el.style.backgroundImage = "url(#{cv.toDataURL()})"
          delete @URL
          return
        URL.revokeObjectURL fileURL
        applyBlob = (blob) =>
          @URL = URL.createObjectURL blob
          @nodes.el.style.backgroundImage = "url(#{@URL})"
        if cv.toBlob
          cv.toBlob applyBlob
          return
        data = atob cv.toDataURL().split(',')[1]

        # DataUrl to Binary code from Aeosynth's 4chan X repo
        l = data.length
        ui8a = new Uint8Array l
        for i in  [0...l]
          ui8a[i] = data.charCodeAt i

        applyBlob new Blob [ui8a], type: 'image/png'

      img.src = fileURL
    rmFile: ->
      delete @file
      delete @filename
      @nodes.el.title = null
      @nodes.el.style.backgroundImage = null
      @nodes.label.hidden = true if QR.spoiler
      @showFileData()
      return unless window.URL
      URL.revokeObjectURL @URL
    showFileData: (hide) ->
      if @file
        QR.nodes.filename.textContent = @filename
        QR.nodes.filename.title       = @filename
        QR.nodes.spoiler.checked      = @spoiler if QR.spoiler
        $.addClass QR.nodes.fileSubmit, 'has-file'
      else
        $.rmClass QR.nodes.fileSubmit, 'has-file'
    pasteText: (file) ->
      reader = new FileReader()
      reader.onload = (e) =>
        text = e.target.result
        if @com
          @com += "\n#{text}"
        else
          @com = text
        if QR.selected is @
          QR.nodes.com.value    = @com
        @nodes.span.textContent = @com
      reader.readAsText file
    dragStart: ->
      $.addClass @, 'drag'
    dragEnd: ->
      $.rmClass @, 'drag'
    dragEnter: ->
      $.addClass @, 'over'
    dragLeave: ->
      $.rmClass @, 'over'
    dragOver: (e) ->
      e.preventDefault()
      e.dataTransfer.dropEffect = 'move'
    drop: ->
      el = $ '.drag', @parentNode
      $.rmClass el, 'drag' # Opera doesn't fire dragEnd if we drop it on something else
      $.rmClass @,  'over'
      return unless @draggable
      index    = (el) -> [el.parentNode.children...].indexOf el
      oldIndex = index el
      newIndex = index @
      (if oldIndex < newIndex then $.after else $.before) @, el
      post = QR.posts.splice(oldIndex, 1)[0]
      QR.posts.splice newIndex, 0, post

  captcha:
    init: ->
      return if d.cookie.indexOf('pass_enabled=1') >= 0
      return unless @isEnabled = !!$.id 'captchaFormPart'
      $.asap (-> $.id 'recaptcha_challenge_field_holder'), @ready.bind @
    ready: ->
      imgContainer = $.el 'div',
        className: 'captcha-img'
        title: 'Reload'
        innerHTML: '<img>'
      input = $.el 'input',
        className: 'captcha-input field'
        title: 'Verification'
        autocomplete: 'off'
        spellcheck: false
      @nodes =
        challenge: $.id 'recaptcha_challenge_field_holder'
        img:       imgContainer.firstChild
        input:     input

      if MutationObserver = window.MutationObserver or window.WebKitMutationObserver or window.OMutationObserver
        observer = new MutationObserver @load.bind @
        observer.observe @nodes.challenge,
          childList: true
      else
        $.on @nodes.challenge, 'DOMNodeInserted', @load.bind @

      $.on imgContainer, 'click',   @reload.bind @
      $.on input,        'keydown', @keydown.bind @
      $.sync 'captchas', @sync
      @sync $.get 'captchas', []
      # start with an uncached captcha
      @reload()

      $.addClass QR.nodes.el, 'has-captcha'
      $.after QR.nodes.com.parentNode, [imgContainer, input]
    sync: (@captchas) ->
      QR.captcha.count()
    getOne: ->
      @clear()
      if captcha = @captchas.shift()
        {challenge, response} = captcha
        @count()
        $.set 'captchas', @captchas
      else
        challenge   = @nodes.img.alt
        if response = @nodes.input.value then @reload()
      if response
        response = response.trim()
        # one-word-captcha:
        # If there's only one word, duplicate it.
        response = "#{response} #{response}" unless /\s/.test response
      {challenge, response}
    save: ->
      return unless response = @nodes.input.value.trim()
      @captchas.push
        challenge: @nodes.img.alt
        response:  response
        timeout:   @timeout
      @count()
      @reload()
      $.set 'captchas', @captchas
    clear: ->
      now = Date.now()
      for captcha, i in @captchas
        break if captcha.timeout > now
      return unless i
      @captchas = @captchas[i..]
      @count()
      $.set 'captchas', @captchas
    load: ->
      return unless @nodes.challenge.firstChild
      # -1 minute to give upload some time.
      @timeout  = Date.now() + $.unsafeWindow.RecaptchaState.timeout * $.SECOND - $.MINUTE
      challenge = @nodes.challenge.firstChild.value
      @nodes.img.alt = challenge
      @nodes.img.src = "//www.google.com/recaptcha/api/image?c=#{challenge}"
      @nodes.input.value = null
      @clear()
    count: ->
      count = @captchas.length
      @nodes.input.placeholder = switch count
        when 0
          'Verification (Shift + Enter to cache)'
        when 1
          'Verification (1 cached captcha)'
        else
          "Verification (#{count} cached captchas)"
      @nodes.input.alt = count # For XTRM RICE.
    reload: (focus) ->
      # the 't' argument prevents the input from being focused
      $.unsafeWindow.Recaptcha.reload 't'
      # Focus if we meant to.
      @nodes.input.focus() if focus
    keydown: (e) ->
      if e.keyCode is 8 and not @nodes.input.value
        @reload()
      else if e.keyCode is 13 and e.shiftKey
        @save()
      else
        return
      e.preventDefault()

  dialog: ->
    dialog = UI.dialog 'qr', 'top:0;right:0;', """
    <div>
      <input type=checkbox id=autohide title=Auto-hide>
      <select title='Create a new thread / Reply'>
        <option value=new>New thread</option>
      </select>
      <span class=move></span>
      <a href=javascript:; class=close title=Close>×</a>
    </div>
    <form>
      <div class=persona>
        <input id=dump-button type=button title='Dump list' value=+>
        <input name=name  data-name=name  title=Name    placeholder=Name    class=field size=1>
        <input name=email data-name=email title=E-mail  placeholder=E-mail  class=field size=1>
        <input name=sub   data-name=sub   title=Subject placeholder=Subject class=field size=1>
      </div>
      <div id=dump-list-container>
        <div id=dump-list></div>
        <a id=add-post href=javascript:; title="Add a post">+</a>
      </div>
      <div class=textarea>
        <textarea data-name=com title=Comment placeholder=Comment class=field></textarea>
        <span id=char-count></span>
      </div>
      <div id=file-n-submit>
        <input id=qr-file-button type=button value='Choose files'>
        <span id=qr-filename-container>
          <span id=qr-no-file>No selected file</span>
          <span id=qr-filename></span>
        </span>
        <a id=qr-filerm href=javascript:; title='Remove file' tabindex=-1>×</a>
        <input type=checkbox id=qr-file-spoiler title='Spoiler image' tabindex=-1>
        <input type=submit>
      </div>
      <input type=file multiple>
    </form>
    """.replace />\s+</g, '><' # get rid of spaces between elements

    QR.nodes = nodes =
      el:         dialog
      move:       $ '.move',             dialog
      autohide:   $ '#autohide',         dialog
      thread:     $ 'select',            dialog
      close:      $ '.close',            dialog
      form:       $ 'form',              dialog
      dumpButton: $ '#dump-button',      dialog
      name:       $ '[data-name=name]',  dialog
      email:      $ '[data-name=email]', dialog
      sub:        $ '[data-name=sub]',   dialog
      com:        $ '[data-name=com]',   dialog
      dumpList:   $ '#dump-list',        dialog
      addPost:    $ '#add-post',         dialog
      charCount:  $ '#char-count',       dialog
      fileSubmit: $ '#file-n-submit',    dialog
      fileButton: $ '#qr-file-button',   dialog
      filename:   $ '#qr-filename',      dialog
      fileRM:     $ '#qr-filerm',        dialog
      spoiler:    $ '#qr-file-spoiler',  dialog
      status:     $ '[type=submit]',     dialog
      fileInput:  $ '[type=file]',       dialog

    # Allow only this board's supported files.
    mimeTypes = $('ul.rules > li').textContent.trim().match(/: (.+)/)[1].toLowerCase().replace /\w+/g, (type) ->
      switch type
        when 'jpg'
          'image/jpeg'
        when 'pdf'
          'application/pdf'
        when 'swf'
          'application/x-shockwave-flash'
        else
          "image/#{type}"
    QR.mimeTypes = mimeTypes.split ', '
    # Add empty mimeType to avoid errors with URLs selected in Window's file dialog.
    QR.mimeTypes.push ''
    nodes.fileInput.max    = $('input[name=MAX_FILE_SIZE]').value
    nodes.fileInput.accept = "text/*, #{mimeTypes}" if $.engine isnt 'presto' # Opera's accept attribute is fucked up

    QR.spoiler = !!$ 'input[name=spoiler]'
    nodes.spoiler.hidden = !QR.spoiler

    if g.BOARD.ID is 'f'
      nodes.flashTag = $.el 'select',
        name: 'filetag'
        innerHTML: """
          <option value=0>Hentai</option>
          <option value=6>Porn</option>
          <option value=1>Japanese</option>
          <option value=2>Anime</option>
          <option value=3>Game</option>
          <option value=5>Loop</option>
          <option value=4 selected>Other</option>
        """
      $.add nodes.form, nodes.flashTag

    # Make a list of threads.
    for thread of g.BOARD.threads
      $.add nodes.thread, $.el 'option',
        value: thread
        textContent: "Thread No.#{thread}"
    $.after nodes.autohide, nodes.thread
    QR.resetThreadSelector()

    for node in [nodes.fileButton, nodes.filename.parentNode]
      $.on node,           'click',  QR.openFileInput
    $.on nodes.autohide,   'change', QR.toggleHide
    $.on nodes.close,      'click',  QR.close
    $.on nodes.dumpButton, 'click',  -> nodes.el.classList.toggle 'dump'
    $.on nodes.addPost,    'click',  -> new QR.post().select()
    $.on nodes.form,       'submit', QR.submit
    $.on nodes.fileRM,     'click',  -> QR.selected.rmFile()
    $.on nodes.spoiler,    'change', -> QR.selected.nodes.spoiler.click()
    $.on nodes.fileInput,  'change', QR.fileInput

    new QR.post().select()
    # save selected post's data
    for name in ['name', 'email', 'sub', 'com']
      $.on nodes[name], 'input', -> QR.selected.save @

    QR.status()
    QR.cooldown.init()
    QR.captcha.init()
    $.add d.body, dialog

    # Create a custom event when the QR dialog is first initialized.
    # Use it to extend the QR's functionalities, or for XTRM RICE.
    $.event 'QRDialogCreation', null, dialog

  submit: (e) ->
    e?.preventDefault()

    if QR.req
      QR.abort()
      return

    if QR.cooldown.seconds
      QR.cooldown.auto = !QR.cooldown.auto
      QR.status()
      return

    post = QR.posts[0]
    post.forceSave()
    if g.BOARD.ID is 'f'
      filetag = QR.nodes.flashTag.value
    threadID = QR.nodes.thread.value

    # prevent errors
    if threadID is 'new'
      threadID = null
      if g.BOARD.ID in ['vg', 'q'] and !post.sub
        err = 'New threads require a subject.'
      else unless post.file or textOnly = !!$ 'input[name=textonly]', $.id 'postForm'
        err = 'No file selected.'
    else if g.BOARD.threads[threadID].isSticky
      err = 'You can\'t reply to this thread anymore.'
    else unless post.com or post.file
      err = 'No file selected.'

    if QR.captcha.isEnabled and !err
      {challenge, response} = QR.captcha.getOne()
      err = 'No valid captcha.' unless response

    if err
      # stop auto-posting
      QR.cooldown.auto = false
      QR.status()
      QR.error err
      return
    QR.cleanNotifications()

    # Enable auto-posting if we have stuff to post, disable it otherwise.
    QR.cooldown.auto = QR.posts.length > 1
    if Conf['Auto-Hide QR'] and !QR.cooldown.auto
      QR.hide()
    if !QR.cooldown.auto and $.x 'ancestor::div[@id="qr"]', d.activeElement
      # Unfocus the focused element if it is one within the QR and we're not auto-posting.
      d.activeElement.blur()

    post.lock()

    postData =
      resto:    threadID
      name:     post.name
      email:    post.email
      sub:      post.sub
      com:      post.com
      upfile:   post.file
      filetag:  filetag
      spoiler:  post.spoiler
      textonly: textOnly
      mode:     'regist'
      pwd: if m = d.cookie.match(/4chan_pass=([^;]+)/) then decodeURIComponent m[1] else $.id('postPassword').value
      recaptcha_challenge_field: challenge
      recaptcha_response_field:  response

    callbacks =
      onload: QR.response
      onerror: ->
        delete QR.req
        post.unlock()
        QR.cooldown.auto = false
        QR.status()
        # Connection error.
        QR.error 'Network error.'
    opts =
      form: $.formData postData
      upCallbacks:
        onload: ->
          # Upload done, waiting for server response.
          QR.req.isUploadFinished = true
          QR.req.uploadEndTime    = Date.now()
          QR.req.progress = '...'
          QR.status()
        onprogress: (e) ->
          # Uploading...
          QR.req.progress = "#{Math.round e.loaded / e.total * 100}%"
          QR.status()

    QR.req = $.ajax $.id('postForm').parentNode.action, callbacks, opts
    # Starting to upload might take some time.
    # Provide some feedback that we're starting to submit.
    QR.req.uploadStartTime = Date.now()
    QR.req.progress = '...'
    QR.status()

  response: ->
    {req} = QR
    delete QR.req

    post = QR.posts[0]
    post.unlock()

    tmpDoc = d.implementation.createHTMLDocument ''
    tmpDoc.documentElement.innerHTML = req.response
    if ban  = $ '.banType', tmpDoc # banned/warning
      board = $('.board', tmpDoc).innerHTML
      err   = $.el 'span', innerHTML:
        if ban.textContent.toLowerCase() is 'banned'
          "You are banned on #{board}! ;_;<br>" +
          "Click <a href=//www.4chan.org/banned target=_blank>here</a> to see the reason."
        else
          "You were issued a warning on #{board} as #{$('.nameBlock', tmpDoc).innerHTML}.<br>" +
          "Reason: #{$('.reason', tmpDoc).innerHTML}"
    else if err = tmpDoc.getElementById 'errmsg' # error!
      $('a', err)?.target = '_blank' # duplicate image link
    else if tmpDoc.title isnt 'Post successful!'
      err = 'Connection error with sys.4chan.org.'
    else if req.status isnt 200
      err = "Error #{req.statusText} (#{req.status})"

    if err
      if /captcha|verification/i.test(err.textContent) or err is 'Connection error with sys.4chan.org.'
        # Remove the obnoxious 4chan Pass ad.
        if /mistyped/i.test err.textContent
          err = 'You seem to have mistyped the CAPTCHA.'
        # Enable auto-post if we have some cached captchas.
        QR.cooldown.auto = if QR.captcha.isEnabled
          !!QR.captcha.captchas.length
        else if err is 'Connection error with sys.4chan.org.'
          true
        else
          # Something must've gone terribly wrong if you get captcha errors without captchas.
          # Don't auto-post indefinitely in that case.
          false
        # Too many frequent mistyped captchas will auto-ban you!
        # On connection error, the post most likely didn't go through.
        QR.cooldown.set delay: 2
      else # stop auto-posting
        QR.cooldown.auto = false
      QR.status()
      QR.error err
      return

    h1 = $ 'h1', tmpDoc
    QR.cleanNotifications()
    QR.notifications.push new Notification 'success', h1.textContent, 5

    persona = $.get 'QR.persona', {}
    persona =
      name:  post.name
      email: if /^sage$/.test post.email then persona.email else post.email
      sub:   if Conf['Remember Subject'] then post.sub      else null
    $.set 'QR.persona', persona

    [_, threadID, postID] = h1.nextSibling.textContent.match /thread:(\d+),no:(\d+)/
    postID   = +postID
    threadID = +threadID or postID

    (QR.yourPosts.threads[threadID] or= []).push postID
    $.set "yourPosts.#{g.BOARD}", QR.yourPosts

    # Post/upload confirmed as successful.
    $.event 'QRPostSuccessful', {
      board: g.BOARD
      threadID
      postID
    }, QR.nodes.el

    # Enable auto-posting if we have stuff to post, disable it otherwise.
    QR.cooldown.auto = QR.posts.length > 1

    post.rm()

    QR.cooldown.set
      req:     req
      post:    post
      isReply: !!threadID

    if threadID is postID # new thread
      $.open "/#{g.BOARD}/res/#{threadID}"
    else if g.VIEW is 'index' and !QR.cooldown.auto # posting from the index
      $.open "/#{g.BOARD}/res/#{threadID}#p#{postID}"

    unless Conf['Persistent QR'] or QR.cooldown.auto
      QR.close()

    QR.status()

  abort: ->
    if QR.req and !QR.req.isUploadFinished
      QR.req.abort()
      delete QR.req
      QR.posts[0].unlock()
      QR.notifications.push new Notification 'info', 'QR upload aborted.', 5
    QR.status()
