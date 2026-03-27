-- lib/ui.lua
-- datafall v1.3: OLED display
-- original pixel rendering restored (15 brightness levels)

local browser = include("datafall/lib/browser")

local ui = {}
ui.browser = browser

ui.page = 1
ui.NUM_PAGES = 2
ui.frame = 0
ui.blink = false

ui.play_pos = 0
ui.byte_data = {}
ui.data_len = 0
ui.filename = "-"
ui.filesize = 0
ui.playing = false
ui.loading = false
ui.rate = 0.25
ui.amp = 0.5
ui.lpf = 8000
ui.lpf_on = true
ui.loop = true
ui.file_type = "?"
ui.focus = false

ui.bit_depth = 3
ui.channels = 2
ui.sample_rate = 2
ui.visual_mode = 1  -- 1=normal, 2=inverted, 3=threshold, 4=1-bit

ui.set_cursor = 1
ui.set_count = 6

local BIT_LABELS = {"1-bit", "4-bit", "8-bit", "16-bit", "24-bit"}
local BIT_VALUES = {1, 4, 8, 16, 24}
local CH_LABELS = {"mono", "stereo"}
local SR_LABELS = {"22050", "44100", "48000"}
local SR_VALUES = {22050, 44100, 48000}
local VIS_LABELS = {"normal", "inverted", "threshold", "1-bit"}

function ui.get_bit_depth() return BIT_VALUES[ui.bit_depth] end
function ui.get_sample_rate() return SR_VALUES[ui.sample_rate] end
function ui.get_channels() return ui.channels end

-- ============================================================
-- WATERFALL: precomputed brightness, grouped by level
-- ============================================================

local function draw_waterfall()
  local W = 128
  local H, top_y
  if ui.focus then H = 56; top_y = 3
  else H = 32; top_y = 12 end

  if ui.data_len < 2 then return end

  local center = math.floor(ui.play_pos * ui.data_len)
  local total = W * H
  local start = math.max(1, center - math.floor(total / 2))
  local mode = ui.visual_mode
  local data = ui.byte_data
  local dlen = ui.data_len

  -- precompute brightness
  local bbuf = {}
  for i = 0, total - 1 do
    local idx = start + i
    if idx >= 1 and idx <= dlen then
      local bv = data[idx] or 0
      local b
      if mode == 2 then
        b = 15 - math.floor(bv * 0.0588)
      elseif mode == 3 then
        b = bv > 127 and 12 or 0
      elseif mode == 4 then
        b = bv > 127 and 15 or 0
      else
        b = math.floor(bv * 0.0588)
      end
      bbuf[i] = b
    else
      bbuf[i] = 0
    end
  end

  -- draw grouped by brightness level
  for lev = 1, 15 do
    screen.level(lev)
    local any = false
    for i = 0, total - 1 do
      if bbuf[i] == lev then
        screen.pixel(i % W, top_y + math.floor(i / W))
        any = true
      end
    end
    if any then screen.fill() end
  end
end

-- ============================================================
-- PAGE 1: FALL
-- ============================================================

local function draw_fall()
  if ui.loading then
    screen.level(ui.blink and 12 or 4)
    screen.move(10, 32); screen.text("LOADING..")
    screen.level(5); screen.move(10, 42)
    local fn = ui.filename
    if #fn > 18 then fn = fn:sub(1, 15) .. ".." end
    screen.text(fn)
    return
  end

  if ui.data_len < 1 then
    screen.level(4); screen.move(10, 32); screen.text("no file loaded")
    screen.level(3); screen.move(10, 42); screen.text("K3 to browse")
    return
  end

  draw_waterfall()

  -- playback line
  if ui.playing then
    local H = ui.focus and 56 or 32
    local top_y = ui.focus and 3 or 12
    local center = math.floor(ui.play_pos * ui.data_len)
    local total = 128 * H
    local start_b = math.max(1, center - math.floor(total / 2))
    local pos_row = math.floor((center - start_b) / 128)
    if pos_row >= 0 and pos_row < H then
      screen.level(15)
      screen.move(0, top_y + pos_row)
      screen.line(128, top_y + pos_row)
      screen.stroke()
    end
  end

  if not ui.focus then
    -- header
    screen.level(0); screen.rect(0, 0, 128, 11); screen.fill()
    screen.level(12); screen.move(1, 8); screen.font_size(8)
    local name = ui.filename
    if #name > 14 then name = name:sub(1, 11) .. ".." end
    screen.text(name)
    screen.level(5); screen.move(78, 8); screen.text(BIT_LABELS[ui.bit_depth])
    screen.level(6); screen.move(108, 8)
    screen.text(string.format("x%.1f", ui.rate))
    if ui.playing then
      screen.level(ui.blink and 15 or 5)
      screen.rect(124, 3, 3, 5); screen.fill()
    end
  end

  -- progress bar (always)
  screen.level(2); screen.rect(0, 61, 128, 2); screen.fill()
  screen.level(10)
  screen.rect(0, 61, math.max(1, math.floor(ui.play_pos * 128)), 2)
  screen.fill()
end

-- ============================================================
-- PAGE 2: SETTINGS
-- ============================================================

local function draw_settings()
  screen.level(12); screen.move(1, 8); screen.font_size(8)
  screen.text("SETTINGS")

  local items = {
    {name = "bit depth",   val = BIT_LABELS[ui.bit_depth]},
    {name = "channels",    val = CH_LABELS[ui.channels]},
    {name = "sample rate", val = SR_LABELS[ui.sample_rate] .. " Hz"},
    {name = "visual mode", val = VIS_LABELS[ui.visual_mode]},
    {name = "lowpass",     val = ui.lpf_on and "ON" or "OFF"},
    {name = ">> APPLY",    val = "K3"},
  }

  for i, item in ipairs(items) do
    local y = 9 + i * 9
    local is_sel = (ui.set_cursor == i)
    if is_sel then
      screen.level(2); screen.rect(0, y - 7, 128, 9); screen.fill()
      screen.level(15); screen.rect(0, y - 7, 2, 9); screen.fill()
    end
    screen.level(is_sel and 12 or 5); screen.move(6, y); screen.text(item.name)
    screen.level(is_sel and 15 or 7); screen.move(125, y); screen.text_right(item.val)
  end
end

-- ============================================================
-- PUBLIC
-- ============================================================

function ui.redraw()
  screen.clear()
  ui.frame = ui.frame + 1
  ui.blink = (ui.frame % 20) < 10

  if browser.active then
    browser.draw(); screen.update(); return
  end

  if ui.page == 1 then draw_fall()
  elseif ui.page == 2 then draw_settings() end

  screen.update()
end

function ui.next_page() ui.page = (ui.page % ui.NUM_PAGES) + 1 end
function ui.prev_page() ui.page = ((ui.page - 2) % ui.NUM_PAGES) + 1 end

return ui
