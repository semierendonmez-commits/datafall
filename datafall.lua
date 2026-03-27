-- datafall
-- v1 @SEMI
-- https://llllllll.co/t/datafall-binary-waterfall-for-norns
--
-- binary waterfall sonification
-- hear and see any file as sound
--
-- E1: page (FALL / SET)
-- FALL: E2 rate, E3 lpf
--       K2 play/stop, K3 browse
-- SET:  E2 select, E3 change
--       K3 apply settings
-- K1+K3: toggle loop

engine.name = "Datafall"

local ui = include("datafall/lib/ui")
local browser = ui.browser

local TEMP_WAV = "/tmp/datafall_temp.wav"
local MAX_BYTES = 2 * 1024 * 1024

local screen_dirty = true
local k1_held = false
local raw_bytes = {}
local raw_count = 0
local loading = false

-- ============================================================
-- WAV WRITER: always writes 2-channel WAV
-- mono mode: same data on both channels
-- stereo mode: alternating bytes L/R
-- ============================================================

local function w16(f, v)
  f:write(string.char(v % 256, math.floor(v / 256) % 256))
end

local function w32(f, v)
  f:write(string.char(v % 256, math.floor(v / 256) % 256,
    math.floor(v / 65536) % 256, math.floor(v / 16777216) % 256))
end

local function build_wav(bytes, count, filepath)
  local bit_depth = ui.get_bit_depth()
  local sr = ui.get_sample_rate()
  local stereo = (ui.get_channels() == 2)
  local bps = math.max(8, bit_depth)  -- WAV bits per sample (min 8)

  -- step 1: interpret raw bytes → sample values (0-255 for display)
  local samples = {}

  if bit_depth == 1 then
    for i = 1, count do
      local b = bytes[i] or 0
      for bit = 7, 0, -1 do
        local val = (math.floor(b / (2 ^ bit)) % 2)
        samples[#samples + 1] = val == 1 and 220 or 36
      end
    end
  elseif bit_depth == 4 then
    for i = 1, count do
      local b = bytes[i] or 0
      samples[#samples + 1] = math.floor(b / 16) * 17
      samples[#samples + 1] = (b % 16) * 17
    end
  elseif bit_depth == 8 then
    for i = 1, count do
      samples[#samples + 1] = bytes[i] or 128
    end
  elseif bit_depth == 16 then
    for i = 1, count - 1, 2 do
      local val = (bytes[i] or 0) + (bytes[i + 1] or 0) * 256
      if val >= 32768 then val = val - 65536 end
      samples[#samples + 1] = math.floor((val + 32768) / 257)
    end
  elseif bit_depth == 24 then
    for i = 1, count - 2, 3 do
      local val = (bytes[i] or 0) + (bytes[i+1] or 0) * 256 + (bytes[i+2] or 0) * 65536
      if val >= 8388608 then val = val - 16777216 end
      samples[#samples + 1] = math.floor((val + 8388608) / 65793)
    end
  end

  if #samples < 2 then return false, {} end

  -- display data (always mono view)
  local display = {}
  for i = 1, #samples do display[i] = samples[i] end

  -- step 2: write ALWAYS 2-channel WAV
  local f = io.open(filepath, "wb")
  if not f then return false, {} end

  local nch = 2  -- always stereo WAV
  local sample_bps = math.max(1, math.floor(bps / 8))
  local num_frames
  if stereo then
    num_frames = math.floor(#samples / 2)
  else
    num_frames = #samples
  end
  if num_frames < 1 then f:close(); return false, {} end

  local data_size = num_frames * nch * sample_bps

  -- RIFF header
  f:write("RIFF"); w32(f, data_size + 36); f:write("WAVE")
  f:write("fmt "); w32(f, 16)
  w16(f, 1)                              -- PCM
  w16(f, nch)                            -- 2 channels always
  w32(f, sr)
  w32(f, sr * nch * sample_bps)          -- byte rate
  w16(f, nch * sample_bps)               -- block align
  w16(f, bps)                            -- bits per sample

  f:write("data"); w32(f, data_size)

  -- write interleaved stereo frames
  local buf = {}
  local bc = 0

  for frame = 0, num_frames - 1 do
    local left_val, right_val

    if stereo then
      -- stereo: alternating samples go L/R
      left_val = samples[frame * 2 + 1] or 128
      right_val = samples[frame * 2 + 2] or 128
    else
      -- mono: same sample to both channels
      local sv = samples[frame + 1] or 128
      left_val = sv
      right_val = sv
    end

    -- write both channels
    for _, sv in ipairs({left_val, right_val}) do
      if bps == 8 then
        bc = bc + 1; buf[bc] = string.char(sv)
      elseif bps == 16 then
        local s16 = math.floor(sv * 257 - 32768)
        s16 = math.max(-32768, math.min(32767, s16))
        if s16 < 0 then s16 = s16 + 65536 end
        bc = bc + 1; buf[bc] = string.char(s16 % 256, math.floor(s16 / 256) % 256)
      elseif bps == 24 then
        local s24 = math.floor(sv * 65793 - 8388608)
        s24 = math.max(-8388608, math.min(8388607, s24))
        if s24 < 0 then s24 = s24 + 16777216 end
        bc = bc + 1; buf[bc] = string.char(s24 % 256, math.floor(s24/256) % 256, math.floor(s24/65536) % 256)
      end
    end

    -- flush periodically
    if bc >= 4096 then
      f:write(table.concat(buf)); buf = {}; bc = 0
    end
  end

  if bc > 0 then f:write(table.concat(buf)) end
  f:close()
  return true, display
end

-- ============================================================
-- FILE TYPE DETECTION
-- ============================================================

local function detect_type(filepath, bytes, count)
  if count >= 4 then
    local b1, b2, b3, b4 = bytes[1], bytes[2], bytes[3], bytes[4]
    if b1==137 and b2==80 and b3==78 and b4==71 then return "PNG" end
    if b1==255 and b2==216 and b3==255 then return "JPEG" end
    if b1==37 and b2==80 and b3==68 and b4==70 then return "PDF" end
    if b1==80 and b2==75 and b3==3 and b4==4 then return "ZIP" end
    if b1==71 and b2==73 and b3==70 then return "GIF" end
    if b1==82 and b2==73 and b3==70 and b4==70 then return "RIFF" end
    if b1==127 and b2==69 and b3==76 and b4==70 then return "ELF" end
    if b1==31 and b2==139 then return "GZIP" end
    if b1==255 and b2>=224 then return "MP3" end
    if b1==102 and b2==76 and b3==97 and b4==67 then return "FLAC" end
    if b1==79 and b2==103 and b3==103 and b4==83 then return "OGG" end
  end
  local ext = filepath:match("%.([^%.]+)$")
  if ext then ext = ext:lower()
    if ext=="lua" or ext=="sc" or ext=="py" or ext=="js" or ext=="sh" then return "CODE"
    elseif ext=="txt" or ext=="md" or ext=="csv" then return "TEXT"
    elseif ext=="html" or ext=="xml" or ext=="json" then return "DATA"
    else return ext:upper():sub(1, 5) end
  end
  return "BIN"
end

-- ============================================================
-- APPLY: rebuild WAV + restart playback
-- ============================================================

local function apply_settings()
  if raw_count < 10 or loading then return end

  clock.run(function()
    loading = true; ui.loading = true; screen_dirty = true

    if ui.playing then engine.stop(); ui.playing = false end

    print("datafall: applying — " .. ui.get_bit_depth() .. "bit "
      .. (ui.get_channels() == 2 and "stereo" or "mono")
      .. " " .. ui.get_sample_rate() .. "Hz")

    clock.sleep(0.05)
    local ok, display = build_wav(raw_bytes, raw_count, TEMP_WAV)

    if not ok then
      print("datafall: build failed")
      loading = false; ui.loading = false
      return
    end

    clock.sleep(0.05)
    engine.load_file(TEMP_WAV)

    ui.byte_data = display
    ui.data_len = #display
    ui.play_pos = 0

    loading = false; ui.loading = false

    clock.sleep(0.3)
    engine.play(ui.rate, ui.amp)
    engine.lpf_on(ui.lpf_on and 1 or 0)
    engine.lpf(ui.lpf)
    ui.playing = true
    screen_dirty = true

    print("datafall: applied — " .. #display .. " samples")
  end)
end

-- ============================================================
-- FILE LOADING
-- ============================================================

local function load_file(filepath)
  if not filepath or filepath == "" or loading then return end

  clock.run(function()
    loading = true; ui.loading = true
    ui.filename = filepath:match("([^/]+)$") or filepath
    ui.page = 1; screen_dirty = true

    print("datafall: loading " .. filepath)

    local f = io.open(filepath, "rb")
    if not f then
      print("datafall: cannot open")
      loading = false; ui.loading = false; return
    end

    raw_bytes = {}; raw_count = 0
    local chunks = 0
    while raw_count < MAX_BYTES do
      local chunk = f:read(4096)
      if not chunk then break end
      for i = 1, #chunk do
        raw_count = raw_count + 1
        raw_bytes[raw_count] = chunk:byte(i)
      end
      chunks = chunks + 1
      if chunks % 32 == 0 then clock.sleep(0) end
    end
    f:close()

    if raw_count < 10 then
      print("datafall: too small")
      loading = false; ui.loading = false; return
    end

    local ftype = detect_type(filepath, raw_bytes, raw_count)
    local fh = io.open(filepath, "rb")
    if fh then ui.filesize = fh:seek("end"); fh:close() end
    ui.file_type = ftype

    print("datafall: " .. raw_count .. " bytes, type=" .. ftype)

    -- build WAV + play (reuse apply logic inline)
    if ui.playing then engine.stop(); ui.playing = false end

    clock.sleep(0.05)
    local ok, display = build_wav(raw_bytes, raw_count, TEMP_WAV)

    if not ok then
      print("datafall: build failed")
      loading = false; ui.loading = false; return
    end

    clock.sleep(0.05)
    engine.load_file(TEMP_WAV)

    ui.byte_data = display
    ui.data_len = #display
    ui.play_pos = 0
    loading = false; ui.loading = false

    clock.sleep(0.3)
    engine.play(ui.rate, ui.amp)
    engine.lpf_on(ui.lpf_on and 1 or 0)
    engine.lpf(ui.lpf)
    ui.playing = true
    screen_dirty = true

    print("datafall: ready — " .. ui.filename)
  end)
end

-- ============================================================
-- PLAYBACK
-- ============================================================

local function toggle_play()
  if ui.data_len < 10 then return end
  if ui.playing then
    engine.stop(); ui.playing = false
  else
    engine.play(ui.rate, ui.amp)
    engine.lpf_on(ui.lpf_on and 1 or 0)
    engine.lpf(ui.lpf)
    ui.playing = true
  end
  screen_dirty = true
end

-- ============================================================
-- PARAMS
-- ============================================================

local function build_params()
  params:add_separator("datafall")

  params:add_control("df_rate", "playback rate",
    controlspec.new(0.01, 4, "exp", 0.01, 0.25))
  params:set_action("df_rate", function(v) ui.rate = v; engine.rate(v) end)

  params:add_control("df_amp", "amplitude",
    controlspec.new(0, 1, "lin", 0.01, 0.5))
  params:set_action("df_amp", function(v) ui.amp = v; engine.amp(v) end)

  params:add_control("df_lpf", "lowpass freq",
    controlspec.new(100, 18000, "exp", 1, 8000, "Hz"))
  params:set_action("df_lpf", function(v) ui.lpf = v; engine.lpf(v) end)

  params:add_option("df_lpf_on", "lowpass on/off", {"on", "off"}, 1)
  params:set_action("df_lpf_on", function(v)
    ui.lpf_on = (v == 1)
    engine.lpf_on(v == 1 and 1 or 0)
  end)

  params:add_option("df_loop", "loop", {"on", "off"}, 1)
  params:set_action("df_loop", function(v)
    ui.loop = (v == 1); engine.loop_mode(v == 1 and 1 or 0)
  end)

  params:add_separator("sonification")

  params:add_option("df_bits", "bit depth",
    {"1-bit", "4-bit", "8-bit", "16-bit", "24-bit"}, 3)
  params:set_action("df_bits", function(v) ui.bit_depth = v end)

  params:add_option("df_ch", "channels", {"mono", "stereo"}, 2)  -- default stereo
  params:set_action("df_ch", function(v) ui.channels = v end)

  params:add_option("df_sr", "sample rate",
    {"22050 Hz", "44100 Hz", "48000 Hz"}, 2)
  params:set_action("df_sr", function(v) ui.sample_rate = v end)

  params:add_option("df_vis", "visual mode",
    {"normal", "inverted", "threshold", "1-bit"}, 1)
  params:set_action("df_vis", function(v) ui.visual_mode = v; screen_dirty = true end)

  params:add_trigger("df_apply", ">> APPLY settings")
  params:set_action("df_apply", function() apply_settings() end)

  params:add_separator("display")

  params:add_option("df_focus", "focus mode", {"off", "on"}, 1)
  params:set_action("df_focus", function(v) ui.focus = (v == 2); screen_dirty = true end)
end

-- ============================================================
-- INIT
-- ============================================================

function init()
  build_params()
  params:default()

  browser.init("/home/we/", function(filepath)
    load_file(filepath)
  end)

  -- redraw clock
  clock.run(function()
    while true do
      clock.sleep(1 / 15)
      -- _menu.mode: norns system flag, true when menu is visible
      if not _menu.mode and (screen_dirty or ui.playing or ui.loading) then
        local ok, err = pcall(ui.redraw)
        if not ok then print("datafall draw: " .. tostring(err)) end
        screen_dirty = false
      end
    end
  end)

  -- position poll
  local pos_poll = poll.set("play_pos")
  pos_poll.callback = function(val) ui.play_pos = val end
  pos_poll.time = 0.07
  pos_poll:start()

  ui.page = 1
  screen_dirty = true
  print("datafall: ready. K3 to browse.")
end

function cleanup()
  engine.stop()
  os.execute("rm -f " .. TEMP_WAV)
end

-- ============================================================
-- ENCODERS
-- ============================================================

function enc(n, d)
  if browser.active then
    if n == 2 then browser.scroll_by(d)
    elseif n == 3 then browser.scroll_by(d * 5) end
    screen_dirty = true; return
  end

  if n == 1 then
    if d > 0 then ui.next_page() else ui.prev_page() end

  elseif n == 2 then
    if ui.page == 1 then
      ui.rate = util.clamp(ui.rate * (d > 0 and 1.05 or (1/1.05)), 0.01, 4)
      params:set("df_rate", ui.rate)
    elseif ui.page == 2 then
      ui.set_cursor = util.clamp(ui.set_cursor + d, 1, ui.set_count)
    end

  elseif n == 3 then
    if ui.page == 1 then
      if ui.lpf_on then
        ui.lpf = util.clamp(ui.lpf * (d > 0 and 1.08 or (1/1.08)), 100, 18000)
        params:set("df_lpf", ui.lpf)
      end
    elseif ui.page == 2 then
      local c = ui.set_cursor
      if c == 1 then
        ui.bit_depth = util.clamp(ui.bit_depth + d, 1, 5)
        params:set("df_bits", ui.bit_depth)
      elseif c == 2 then
        ui.channels = util.clamp(ui.channels + d, 1, 2)
        params:set("df_ch", ui.channels)
      elseif c == 3 then
        ui.sample_rate = util.clamp(ui.sample_rate + d, 1, 3)
        params:set("df_sr", ui.sample_rate)
      elseif c == 4 then
        ui.visual_mode = util.clamp(ui.visual_mode + d, 1, 4)
        params:set("df_vis", ui.visual_mode)
      elseif c == 5 then
        ui.lpf_on = not ui.lpf_on
        params:set("df_lpf_on", ui.lpf_on and 1 or 2)
      end
      -- c == 6 is APPLY (handled by K3)
    end
  end
  screen_dirty = true
end

-- ============================================================
-- KEYS
-- ============================================================

function key(n, z)
  if n == 1 then
    k1_held = (z == 1)
    return
  end
  if z ~= 1 then return end

  if browser.active then
    if n == 2 then browser.go_back()
    elseif n == 3 then browser.action() end
    screen_dirty = true; return
  end

  if n == 2 then
    toggle_play()

  elseif n == 3 then
    if k1_held then
      params:set("df_loop", ui.loop and 2 or 1)
    else
      if ui.page == 1 then
        browser.active = true
      elseif ui.page == 2 then
        apply_settings()
      end
    end
  end
  screen_dirty = true
end

-- ============================================================
-- REDRAW
-- ============================================================

function redraw()
  ui.redraw()
end
