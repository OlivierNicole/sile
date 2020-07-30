-- Japaneese language support defines units which are useful here
SILE.languageSupport.loadLanguage("ja")

SILE.registerCommand("ruby:font", function (_, _)
  SILE.call("font", { size = "0.6zw", weight = 800 })
end)

SILE.settings.declare({
    parameter = "ruby.height",
    type = "measurement",
    default = SILE.measurement("1zw"),
    help = "Vertical offset between the ruby and the main text"
  })

SILE.settings.declare({
    parameter = "ruby.latinspacer",
    type = "glue",
    default = SILE.nodefactory.glue("0.25em"),
    help = "Glue added between consecutive Latin ruby"
  })

local isLatin = function (char)
  return (char > 0x20 and char <= 0x24F) or (char >= 0x300 and char <= 0x36F)
    or (char >= 0x1DC0 and char <= 0x1EFF) or (char >= 0x2C60 and char <= 0x2c7F)
end

local checkIfSpacerNeeded = function (reading)
  -- First, did we have a ruby node at all?
  if not SILE.scratch.lastRubyBox then return end
  -- Does the current reading start with a latin?
  if not isLatin(SU.codepoint(SU.firstChar(reading))) then return end
  -- Did we have some nodes recently?
  local top = #SILE.typesetter.state.nodes
  if top < 2 then return end
  -- Have we had other stuff since the last ruby node?
  if SILE.typesetter.state.nodes[top] ~= SILE.scratch.lastRubyBox
     and SILE.typesetter.state.nodes[top-1] ~= SILE.scratch.lastRubyBox then
    return
  end
  -- Does the previous reading end with a latin?
  if not isLatin(SU.codepoint(SU.lastChar(SILE.scratch.lastRubyText))) then return end
  -- OK, we need a spacer!
  SILE.typesetter:pushGlue(SILE.settings.get("ruby.latinspacer"))
end

SILE.registerCommand("ruby", function (options, content)
  local reading = SU.required(options, "reading", "\\ruby")
  SILE.typesetter:setpar("")

  checkIfSpacerNeeded(reading)

  SILE.call("hbox", {}, function ()
    SILE.settings.temporarily(function ()
      SILE.call("noindent")
      SILE.call("ruby:font")
      SILE.typesetter:typeset(reading)
    end)
  end)
  local rubybox = SILE.typesetter.state.nodes[#SILE.typesetter.state.nodes]
  rubybox.outputYourself = function (self, typesetter, line)
    local ox = typesetter.frame.state.cursorX
    local oy = typesetter.frame.state.cursorY
    typesetter.frame:advanceWritingDirection(rubybox.width)
    typesetter.frame:advancePageDirection(-SILE.settings.get("ruby.height"))
    SILE.outputter.moveTo(typesetter.frame.state.cursorX, typesetter.frame.state.cursorY)
    for i = 1, #(self.value) do
      local node = self.value[i]
      node:outputYourself(typesetter, line)
    end
    typesetter.frame.state.cursorX = ox
    typesetter.frame.state.cursorY = oy
  end
  -- measure the content
  SILE.call("hbox", {}, content)
  local cbox = SILE.typesetter.state.nodes[#SILE.typesetter.state.nodes]
  SU.debug("ruby", "base box is " .. cbox)
  SU.debug("ruby", "reading is  " .. rubybox)
  if cbox:lineContribution() > rubybox:lineContribution() then
    SU.debug("ruby", "Base is longer, offsetting ruby to fit")
    -- This is actually the offset against the base
    rubybox.width = SILE.length(cbox:lineContribution() - rubybox:lineContribution())/2
  else
    local diff = rubybox:lineContribution() - cbox:lineContribution()
    local to_insert = SILE.length(diff / 2)
    SU.debug("ruby", "Ruby is longer, inserting " .. to_insert .. " either side of base")
    cbox.width = rubybox:lineContribution()
    rubybox.height = 0
    rubybox.width = 0
    -- add spaces at beginning and end
    table.insert(cbox.value, 1, SILE.nodefactory.glue(to_insert))
    table.insert(cbox.value, SILE.nodefactory.glue(to_insert))
  end
  SILE.scratch.lastRubyBox = rubybox
  SILE.scratch.lastRubyText = reading
end)

return {
  documentation = [[
\begin{document}
Japanese texts often contain pronunciation hints (called \em{furigana}) for
difficult kanji or foreign words. These hints are traditionally placed either
above (in horizontal typesetting) or beside (in vertical typesetting) the word
that they explain. The typesetting term for these glosses is \em{ruby}.

The \code{ruby} package provides the \code{\\ruby[reading=...]\{...\}} command
which sets a piece of ruby above or beside the base text. For example:

\set[parameter=ruby.height, value=12pt]
\language[main=ja]{}

\define[command=ruby:font]{\font[family=Noto Sans CJK JP,size=6pt]}
\begin{verbatim}
\line
\\ruby[reading=\font[family=Noto Sans CJK JP]{れいわ}]\{\font[family=Noto Sans CJK JP]{令和}\}
\line
\end{verbatim}

Produces:
\medskip
\font[family=Noto Sans CJK JP]{
  \ruby[reading=れいわ]{令和}
}

\language[main=en]

\end{document}
]]
}
