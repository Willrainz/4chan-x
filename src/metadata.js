// ==UserScript==
// @name         <%= meta.name %>
// @version      <%= version %>
// @namespace    <%= name %>
// @description  Cross-browser userscript for maximum lurking on 4chan.
// @copyright    2009-2011 James Campos <james.r.campos@gmail.com>
// @copyright    2012-<%= grunt.template.today('yyyy') %> Nicolas Stepien <stepien.nicolas@gmail.com>
// @license      MIT; http://en.wikipedia.org/wiki/Mit_license
// @match        *://boards.4chan.org/*
// @match        *://images.4chan.org/*
// @match        *://sys.4chan.org/*
// @match        *://api.4chan.org/*
// @grant        GM_getValue
// @grant        GM_setValue
// @grant        GM_deleteValue
// @grant        GM_openInTab
// @run-at       document-start
// @updateURL    <%= meta.repo %>raw/<%= meta.mainBranch %>/<%= meta.files.metajs %>
// @downloadURL  <%= meta.repo %>raw/<%= meta.mainBranch %>/<%= meta.files.userjs %>
// @icon         data:image/gif;base64,<%= grunt.file.read('img/icon.gif', {encoding: 'base64'}) %>
// ==/UserScript==
