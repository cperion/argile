-- SDL3_ttf-backed text measurement + rendering helpers for Argile render commands.
--
-- This module is intentionally parameterized so it can be reused with:
-- - Terra-native Argile API tables (e.g. `ui` from `argile.src.builder`)
-- - Portable ABI tables from bindings (e.g. `arg` from `backends.sdl3.bindings`)

local M = {}

function M.create(opts)
    opts = opts or {}
    local api = assert(opts.api, "text_backend.create: opts.api is required")
    local sdl = assert(opts.sdl, "text_backend.create: opts.sdl is required")

    local max_font_ids = opts.max_font_ids or 16
    local max_cached_fonts = opts.max_cached_fonts or 64
    local default_font_size = opts.default_font_size or 16

    local struct FontFamilyEntry {
        valid : bool,
        path : &int8,
    }

    local struct FontCacheEntry {
        used : bool,
        fontId : uint16,
        fontSize : uint16,
        font : &sdl.TTF_Font,
    }

    local struct TextBackend {
        fontFamilies : FontFamilyEntry[max_font_ids],
        fontCache : FontCacheEntry[max_cached_fonts],
    }

    terra TextBackend:init()
        var i: int = 0
        while i < max_font_ids do
            self.fontFamilies[i].valid = false
            self.fontFamilies[i].path = nil
            i = i + 1
        end

        i = 0
        while i < max_cached_fonts do
            self.fontCache[i].used = false
            self.fontCache[i].fontId = 0
            self.fontCache[i].fontSize = 0
            self.fontCache[i].font = nil
            i = i + 1
        end
    end

    terra TextBackend:shutdown()
        var i: int = 0
        while i < max_cached_fonts do
            if self.fontCache[i].used and self.fontCache[i].font ~= nil then
                sdl.TTF_CloseFont(self.fontCache[i].font)
            end
            self.fontCache[i].used = false
            self.fontCache[i].font = nil
            self.fontCache[i].fontId = 0
            self.fontCache[i].fontSize = 0
            i = i + 1
        end
    end

    terra TextBackend:register_font(font_id: uint16, path: &int8) : bool
        var idx = [int](font_id)
        if idx < 0 or idx >= max_font_ids or path == nil then
            return false
        end

        self.fontFamilies[idx].valid = true
        self.fontFamilies[idx].path = path

        -- Invalidate existing cache entries for this font family.
        var i: int = 0
        while i < max_cached_fonts do
            if self.fontCache[i].used and self.fontCache[i].fontId == font_id then
                if self.fontCache[i].font ~= nil then
                    sdl.TTF_CloseFont(self.fontCache[i].font)
                end
                self.fontCache[i].used = false
                self.fontCache[i].font = nil
                self.fontCache[i].fontSize = 0
            end
            i = i + 1
        end

        return true
    end

    terra TextBackend:get_font(font_id: uint16, font_size: uint16) : &sdl.TTF_Font
        var resolved_id = font_id
        var size = font_size
        if size == 0 then
            size = [uint16](default_font_size)
        end

        var path: &int8 = nil
        var idx = [int](resolved_id)
        if idx >= 0 and idx < max_font_ids and self.fontFamilies[idx].valid then
            path = self.fontFamilies[idx].path
        end

        if path == nil then
            resolved_id = 0
            if self.fontFamilies[0].valid then
                path = self.fontFamilies[0].path
            else
                return nil
            end
        end

        var i: int = 0
        while i < max_cached_fonts do
            if self.fontCache[i].used and
               self.fontCache[i].fontId == resolved_id and
               self.fontCache[i].fontSize == size then
                return self.fontCache[i].font
            end
            i = i + 1
        end

        var free_index: int = -1
        i = 0
        while i < max_cached_fonts do
            if not self.fontCache[i].used then
                free_index = i
                break
            end
            i = i + 1
        end
        if free_index < 0 then
            return nil
        end

        var font = sdl.TTF_OpenFont(path, [float](size))
        if font == nil then
            return nil
        end
        sdl.TTF_SetFontHinting(font, sdl.TTF_HINTING_NORMAL)

        self.fontCache[free_index].used = true
        self.fontCache[free_index].fontId = resolved_id
        self.fontCache[free_index].fontSize = size
        self.fontCache[free_index].font = font
        return font
    end

    local terra color_to_u8(v: float) : uint8
        if v < 0.0 then return 0 end
        if v > 1.0 then return 255 end
        return [uint8](v * 255.0 + 0.5)
    end

    local terra snap_to_pixel(v: float) : float
        if v >= 0.0 then
            return [float]([int](v + 0.5))
        end
        return [float]([int](v - 0.5))
    end

    local terra measure_text(text: &api.StringSlice, config: &api.TextConfig, user_data: &opaque, out: &api.Dimensions) : int32
        if out == nil then return 0 end
        out.width = 0.0
        out.height = 0.0
        if text == nil then return 0 end

        var backend = [&TextBackend](user_data)
        var font_id: uint16 = 0
        var font_size: uint16 = [uint16](default_font_size)
        if config ~= nil then
            font_id = config.fontId
            if config.fontSize > 0 then
                font_size = config.fontSize
            end
        end

        if backend ~= nil then
            var font = backend:get_font(font_id, font_size)
            if font ~= nil then
                if text.chars ~= nil and text.length > 0 then
                    var w: int = 0
                    var h: int = 0
                    if sdl.TTF_GetStringSize(font, text.chars, [uint64](text.length), &w, &h) then
                        out.width = [float](w)
                        out.height = [float](h)
                        return 1
                    end
                else
                    var line_skip = sdl.TTF_GetFontLineSkip(font)
                    if line_skip > 0 then
                        out.height = [float](line_skip)
                    else
                        out.height = [float](font_size)
                    end
                    return 1
                end
            end
        end

        -- Fallback heuristic so layout still works if the backend is unavailable.
        var len: int = [int](text.length)
        if len < 0 then len = 0 end
        out.width = [float](len) * [float](font_size) * 0.6
        out.height = [float](font_size)
        return 1
    end

    local terra draw_text(renderer: &sdl.SDL_Renderer, backend: &TextBackend, cmd: &api.RenderCommand)
        if renderer == nil or backend == nil or cmd == nil then return end

        var t = cmd.renderData.text
        if t.stringContents.chars == nil or t.stringContents.length <= 0 then
            return
        end

        var font = backend:get_font(t.fontId, t.fontSize)
        if font == nil then return end

        var c: sdl.SDL_Color
        c.r = color_to_u8(t.textColor.r)
        c.g = color_to_u8(t.textColor.g)
        c.b = color_to_u8(t.textColor.b)
        c.a = color_to_u8(t.textColor.a)

        var surf = sdl.TTF_RenderText_Blended(font, t.stringContents.chars, [uint64](t.stringContents.length), c)
        if surf == nil then return end

        var tex = sdl.SDL_CreateTextureFromSurface(renderer, surf)
        sdl.SDL_DestroySurface(surf)
        if tex == nil then return end

        var bb = cmd.boundingBox
        var dst: sdl.SDL_FRect
        dst.x = snap_to_pixel(bb.x)
        dst.y = snap_to_pixel(bb.y)
        sdl.SDL_GetTextureSize(tex, &dst.w, &dst.h)
        sdl.SDL_RenderTexture(renderer, tex, nil, &dst)
        sdl.SDL_DestroyTexture(tex)
    end

    return {
        TextBackend = TextBackend,
        measure_text = measure_text,
        draw_text = draw_text,
        default_font_size = default_font_size,
        max_font_ids = max_font_ids,
        max_cached_fonts = max_cached_fonts,
    }
end

return M
