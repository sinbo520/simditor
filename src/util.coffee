
class Util extends Plugin

  @className: 'Util'

  constructor: (args...) ->
    super args...
    @phBr = '' if @browser.msie and @browser.version < 11
    @editor = @widget

  _init: ->

  phBr: '<br/>'

  os: (->
    if /Mac/.test navigator.appVersion
      mac: true
    else if /Linux/.test navigator.appVersion
      linux: true
    else if /Win/.test navigator.appVersion
      win: true
    else if /X11/.test navigator.appVersion
      unix: true
    else
      {}
  )()

  browser: (->
    ua = navigator.userAgent
    ie = /(msie|trident)/i.test(ua)
    chrome = /chrome|crios/i.test(ua)
    safari = /safari/i.test(ua) && !chrome
    firefox = /firefox/i.test(ua)

    if ie
      msie: true
      version: ua.match(/(msie |rv:)(\d+(\.\d+)?)/i)[2]
    else if chrome
      webkit: true
      chrome: true
      version: ua.match(/(?:chrome|crios)\/(\d+(\.\d+)?)/i)[1]
    else if safari
      webkit: true
      safari: true
      version: ua.match(/version\/(\d+(\.\d+)?)/i)[1]
    else if firefox
      mozilla: true
      firefox: true
      version: ua.match(/firefox\/(\d+(\.\d+)?)/i)[1]
    else
      {}
  )()

  metaKey: (e) ->
    isMac = /Mac/.test navigator.userAgent
    if isMac then e.metaKey else e.ctrlKey

  isEmptyNode: (node) ->
    $node = $(node)
    !$node.text() and !$node.find(':not(br)').length

  isBlockNode: (node) ->
    node = $(node)[0]
    if !node or node.nodeType == 3
      return false

    /^(div|p|ul|ol|li|blockquote|hr|pre|h1|h2|h3|h4|table)$/.test node.nodeName.toLowerCase()

  closestBlockEl: (node) ->
    unless node?
      range = @editor.selection.getRange()
      node = range?.commonAncestorContainer

    $node = $(node)

    return null unless $node.length

    blockEl = $node.parentsUntil(@editor.body).addBack()
    blockEl = blockEl.filter (i) =>
      @isBlockNode blockEl.eq(i)

    if blockEl.length then blockEl.last() else null

  furthestNode: (node, filter) ->
    unless node?
      range = @editor.selection.getRange()
      node = range?.commonAncestorContainer

    $node = $(node)

    return null unless $node.length

    blockEl = $node.parentsUntil(@editor.body).addBack()
    blockEl = blockEl.filter (i) =>
      $n = blockEl.eq(i)
      if $.isFunction filter
        return filter $n
      else
        return $n.is(filter)

    if blockEl.length then blockEl.first() else null


  furthestBlockEl: (node) ->
    @furthestNode(node, @isBlockNode)
    #unless node?
      #range = @editor.selection.getRange()
      #node = range?.commonAncestorContainer

    #$node = $(node)

    #return null unless $node.length

    #blockEl = $node.parentsUntil(@editor.body).addBack()
    #blockEl = blockEl.filter (i) =>
      #@isBlockNode blockEl.eq(i)

    #if blockEl.length then blockEl.first() else null

  getNodeLength: (node) ->
    switch node.nodeType
      when 7, 10 then 0
      when 3, 8 then node.length
      else node.childNodes.length


  traverseUp:(callback, node) ->
    unless node?
      range = @editor.selection.getRange()
      node = range?.commonAncestorContainer

    if !node? or !$.contains(@editor.body[0], node)
      return false

    nodes = $(node).parentsUntil(@editor.body).get()
    nodes.unshift node
    for n in nodes
      result = callback n
      break if result == false

  getShortcutKey: (e) ->
    shortcutName = []
    shortcutName.push 'shift' if e.shiftKey
    shortcutName.push 'ctrl' if e.ctrlKey
    shortcutName.push 'alt' if e.altKey
    shortcutName.push 'cmd' if e.metaKey
    shortcutName.push e.which
    shortcutName.join '+'

  indent: () ->
    $blockEl = @editor.util.closestBlockEl()
    return false unless $blockEl and $blockEl.length > 0

    if $blockEl.is('pre')
      spaceNode = document.createTextNode '\u00A0\u00A0'
      @editor.selection.insertNode spaceNode
    else if $blockEl.is('li')
      $parentLi = $blockEl.prev('li')
      return false if $parentLi.length < 1

      @editor.selection.save()
      tagName = $blockEl.parent()[0].tagName
      $childList = $parentLi.children('ul, ol')

      if $childList.length > 0
        $childList.append $blockEl
      else
        $('<' + tagName + '/>')
          .append($blockEl)
          .appendTo($parentLi)

      @editor.selection.restore()
    else if $blockEl.is 'p, h1, h2, h3, h4'
      indentLevel = $blockEl.attr('data-indent') ? 0
      indentLevel = indentLevel * 1 + 1
      indentLevel = 10 if indentLevel > 10
      $blockEl.attr 'data-indent', indentLevel
    else if $blockEl.is 'table'
      range = @editor.selection.getRange()
      $td = $(range.commonAncestorContainer).closest('td')
      $nextTd = $td.next('td')
      $nextTd = $td.parent('tr').next('tr').find('td:first') unless $nextTd.length > 0
      return false unless $td.length > 0 and $nextTd.length > 0
      @editor.selection.setRangeAtEndOf $nextTd
    else
      spaceNode = document.createTextNode '\u00A0\u00A0\u00A0\u00A0'
      @editor.selection.insertNode spaceNode

    @editor.trigger 'valuechanged'
    @editor.trigger 'selectionchanged'
    true

  outdent: () ->
    $blockEl = @editor.util.closestBlockEl()
    return false unless $blockEl and $blockEl.length > 0

    if $blockEl.is('pre')
      # TODO: outdent in code block
      return false
    else if $blockEl.is('li')
      $parent = $blockEl.parent()
      $parentLi = $parent.parent('li')

      if $parentLi.length < 1
        button = @editor.toolbar.findButton $parent[0].tagName.toLowerCase()
        button?.command()
        return false

      @editor.selection.save()

      if $blockEl.next('li').length > 0
        $('<' + $parent[0].tagName + '/>')
          .append($blockEl.nextAll('li'))
          .appendTo($blockEl)

      $blockEl.insertAfter $parentLi
      $parent.remove() if $parent.children('li').length < 1
      @editor.selection.restore()
    else if $blockEl.is 'p, h1, h2, h3, h4'
      indentLevel = $blockEl.attr('data-indent') ? 0
      indentLevel = indentLevel * 1 - 1
      indentLevel = 0 if indentLevel < 0
      $blockEl.attr 'data-indent', indentLevel
    else if $blockEl.is 'table'
      range = @editor.selection.getRange()
      $td = $(range.commonAncestorContainer).closest('td')
      $prevTd = $td.prev('td')
      $prevTd = $td.parent('tr').prev('tr').find('td:last') unless $prevTd.length > 0
      return false unless $td.length > 0 and $prevTd.length > 0
      @editor.selection.setRangeAtEndOf $prevTd
    else
      return false

    @editor.trigger 'valuechanged'
    @editor.trigger 'selectionchanged'
    true
