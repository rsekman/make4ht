local log = logging.new "htlatex"

local error_logparser = require("make4ht-errorlogparser")

local Make = Make or {}
-- this function reads the LaTeX log file and tries to detect fatal errors in the compilation
local function testlogfile(par)
  local logfile = par.input .. ".log"
  local f = io.open(logfile,"r")
  if not f then
    log:warning("Make4ht: cannot open log file "..logfile)
    return 1
  end
  local content = f:read("*a")
  -- test only the end of the log file, no need to run search functions on everything
  local text = content:sub(-1256)
  f:close()
  -- parse log file for all errors in non-interactive modes
  if par.interaction~="errorstopmode" then
    -- the error log parsing can be slow, so detect errors first
    if content:match("\n!")  then
      local errors, chunks = error_logparser.parse(content)
      if #errors > 0 then
        log:error("Compilation errors in the htlatex run")
        log:error("Filename", "Line", "Message")
        for _, err in ipairs(errors) do
          log:error(err.filename or "?", err.line or "?", err.error)
        end
      end
    end
  end
  -- test for fatal errors
  if text:match("No pages of output") or text:match("TeX capacity exceeded, sorry") or text:match("That makes 100 errors") or text:match("Emergency stop") then return 1 end
  return 0
end


-- Make this function available in the build files
Make.testlogfile = testlogfile
--env.Make:add("htlatex", "${htlatex} ${latex_par} '\\\makeatletter\\def\\HCode{\\futurelet\\HCode\\HChar}\\def\\HChar{\\ifx\"\\HCode\\def\\HCode\"##1\"{\\Link##1}\\expandafter\\HCode\\else\\expandafter\\Link\\fi}\\def\\Link#1.a.b.c.{\\g@addto@macro\\@documentclasshook{\\RequirePackage[#1,html]{tex4ht}\\let\\HCode\\documentstyle\\def\\documentstyle{\\let\\documentstyle\\HCode\\expandafter\\def\\csname tex4ht\\endcsname{#1,html}\\def\\HCode####1{\\documentstyle[tex4ht,}\\@ifnextchar[{\\HCode}{\\documentstyle[tex4ht]}}}\\makeatother\\HCode '${config}${tex4ht_sty_par}'.a.b.c.\\input ' ${input}")

-- template for calling LaTeX with tex4ht loaded
Make.latex_command = "${htlatex} --interaction=${interaction} ${latex_par} '\\makeatletter"..
"\\def\\HCode{\\futurelet\\HCode\\HChar}\\def\\HChar{\\ifx\"\\HCode"..
"\\def\\HCode\"##1\"{\\Link##1}\\expandafter\\HCode\\else"..
"\\expandafter\\Link\\fi}\\def\\Link#1.a.b.c.{\\g@addto@macro"..
"\\@documentclasshook{\\RequirePackage[#1,html]{tex4ht}${packages}}"..
"\\let\\HCode\\documentstyle\\def\\documentstyle{\\let\\documentstyle"..
"\\HCode\\expandafter\\def\\csname tex4ht\\endcsname{#1,html}\\def"..
"\\HCode####1{\\documentstyle[tex4ht,}\\@ifnextchar[{\\HCode}{"..
"\\documentstyle[tex4ht]}}}\\makeatother\\HCode ${tex4ht_sty_par}.a.b.c."..
"\\input \"\\detokenize{${tex_file}}\"'"


local m = {}

function m.htlatex(par)
  local settings = get_filter_settings "htlatex" or {}
  local command = Make.latex_command
  if os.type == "windows" then
    command = command:gsub("'",'')
  end
  -- the interaction parameter is configurable in settings or as a parameter
  par.interaction = par.interaction or settings.interaction or "batchmode"
  command = command % par
  log:info("LaTeX call: "..command)
  os.execute(command)
  return Make.testlogfile(par)
end

return m
