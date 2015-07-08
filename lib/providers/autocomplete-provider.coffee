fuzzaldrin = require 'fuzzaldrin'
minimatch = require 'minimatch'
exec = require "child_process"

proxy = require "../services/php-proxy.coffee"
parser = require "../services/php-file-parser.coffee"
AbstractProvider = require "./abstract-provider"

module.exports =
# Other autocompletions (Everything is here !!)
# WORK IN PROGRESS
class AutocompleteProvider extends AbstractProvider
  methods: []
  functionOnly: true

  ###*
   * Get suggestions from the provider (@see provider-api)
   * @return array
  ###
  fetchSuggestions: ({editor, bufferPosition, scopeDescriptor, prefix}) ->
    # "new" keyword or word starting with capital letter
    @regex = /(?:[\$]?)(?![this])([a-zA-Z0-9_]+)(?:\([.]*\))?(?:->)?/g

    prefix = @getPrefix(editor, bufferPosition)

    elements = parser.getStackClasses(editor, bufferPosition)
    return unless elements?

    className = @parseElements(editor, bufferPosition, elements)
    return unless className?

    @methods = proxy.methods(className)
    return unless @methods.names?

    elements = prefix.split('->')
    suggestions = @findSuggestionsForPrefix(elements[elements.length-1].trim())
    return unless suggestions.length
    return suggestions

  ###*
   * Returns suggestions available matching the given prefix
   * @param {string} prefix Prefix to match
   * @return array
  ###
  findSuggestionsForPrefix: (prefix) ->
    # Filter the words using fuzzaldrin
    words = fuzzaldrin.filter @methods.names, prefix

    # Builds suggestions for the words
    suggestions = []
    for word in words
      element = @methods.values[word]

      returnValues = element.args.return.split('\\')
      # Methods
      if element.isMethod
        suggestions.push
          text: word,
          type: 'method',
          snippet: @getFunctionSnippet(word, element.args),
          leftLabel: returnValues[returnValues.length - 1]

      # Constants and public properties
      else
        suggestions.push
          text: word,
          type: 'property'
          leftLabel: returnValues[returnValues.length - 1]

    return suggestions

  ###*
   * Parse all elements from the given array to return the last className (if any)
   * @param  Array elements Elements to parse
   * @return string|null full class name of the last element
  ###
  parseElements: (editor, bufferPosition, elements) ->
    loop_index = 0
    className  = null

    for element in elements
      # $this keyword
      if loop_index == 0
        if element == '$this'
          className = parser.getCurrentClass(editor, bufferPosition)
          loop_index++
          continue
        else
          className = parser.getVariableType(editor, bufferPosition, element)
          loop_index++
          continue

      # Last element
      if loop_index >= elements.length - 1
        break

      if className == null
        break

      methods = proxy.autocomplete(className, element)

      # Element not found or no return value
      if not methods.class? or not parser.isClass(methods.class)
        className = null
        break

      className = methods.class
      loop_index++

    # If no data or a valid end of line, OK
    if elements.length > 0 and (elements[elements.length-1].length == 0 or elements[elements.length-1].match(/([a-zA-Z0-9]$)/g))
      return className

    return
