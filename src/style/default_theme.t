local style = require("src/style/core")

local theme = {}

theme.colors = {
    primary_50  = style.color(0.969, 0.978, 1.000, 1.0),
    primary_100 = style.color(0.910, 0.937, 0.988, 1.0),
    primary_200 = style.color(0.812, 0.867, 0.973, 1.0),
    primary_300 = style.color(0.655, 0.757, 0.953, 1.0),
    primary_400 = style.color(0.459, 0.612, 0.925, 1.0),
    primary_500 = style.color(0.294, 0.475, 0.875, 1.0),
    primary_600 = style.color(0.216, 0.384, 0.820, 1.0),
    primary_700 = style.color(0.176, 0.314, 0.714, 1.0),
    primary_800 = style.color(0.165, 0.271, 0.588, 1.0),
    primary_900 = style.color(0.157, 0.239, 0.490, 1.0),
    
    surface_0   = style.color(0.980, 0.980, 0.980, 1.0),
    surface_50   = style.color(0.961, 0.961, 0.961, 1.0),
    surface_100  = style.color(0.922, 0.922, 0.922, 1.0),
    surface_200  = style.color(0.863, 0.863, 0.863, 1.0),
    surface_300  = style.color(0.745, 0.745, 0.745, 1.0),
    surface_400  = style.color(0.588, 0.588, 0.588, 1.0),
    surface_500  = style.color(0.467, 0.467, 0.467, 1.0),
    surface_600  = style.color(0.376, 0.376, 0.376, 1.0),
    surface_700  = style.color(0.278, 0.278, 0.278, 1.0),
    surface_800  = style.color(0.173, 0.173, 0.173, 1.0),
    surface_900  = style.color(0.098, 0.098, 0.098, 1.0),
    
    fg_default  = style.color(0.098, 0.098, 0.098, 1.0),
    fg_muted    = style.color(0.467, 0.467, 0.467, 1.0),
    fg_subtle   = style.color(0.745, 0.745, 0.745, 1.0),
    
    border_default = style.color(0.863, 0.863, 0.863, 1.0),
    border_muted   = style.color(0.922, 0.922, 0.922, 1.0),
    
    white = style.color(1.0, 1.0, 1.0, 1.0),
    black = style.color(0.0, 0.0, 0.0, 1.0),
    transparent = style.color(0.0, 0.0, 0.0, 0.0),
}

theme.space = {
    none = 0,
    xs = 2,
    sm = 4,
    md = 8,
    lg = 16,
    xl = 24,
    xxl = 32,
    xxxl = 48,
}

theme.radii = {
    none = 0,
    xs = 2,
    sm = 4,
    md = 6,
    lg = 8,
    xl = 12,
    xxl = 16,
    full = 9999,
}

theme.font_sizes = {
    xs = 10,
    sm = 12,
    md = 14,
    lg = 16,
    xl = 18,
    xxl = 24,
    xxxl = 32,
    display = 48,
}

theme.line_heights = {
    tight = 1.0,
    snug = 1.25,
    normal = 1.5,
    relaxed = 1.75,
    loose = 2.0,
}

local function patch_with(opts, base_patch)
    if not opts then return base_patch end
    return style.merge_patch(base_patch, opts)
end

theme.panel = function(opts)
    local patch = style.StylePatch:new()
    patch.shared = {
        backgroundColor = theme.colors.surface_50,
        cornerRadius = style.corner_radius(theme.radii.md),
    }
    patch.border = {
        color = theme.colors.border_default,
        width = style.border_width(1),
    }
    return patch_with(opts, patch)
end

theme.panel_body = function(opts)
    local patch = style.StylePatch:new()
    patch.shared = {
        backgroundColor = theme.colors.transparent,
    }
    return patch_with(opts, patch)
end

theme.button = function(opts)
    local tone = opts and opts.tone or "primary"
    local size = opts and opts.size or "md"
    
    local base_color = theme.colors.primary_500
    local hover_color = theme.colors.primary_600
    local text_color = theme.colors.white
    
    if tone == "secondary" then
        base_color = theme.colors.surface_200
        hover_color = theme.colors.surface_300
        text_color = theme.colors.fg_default
    elseif tone == "ghost" then
        base_color = theme.colors.transparent
        hover_color = theme.colors.surface_100
        text_color = theme.colors.fg_default
    elseif tone == "danger" then
        base_color = style.color(0.8, 0.2, 0.2, 1.0)
        hover_color = style.color(0.7, 0.15, 0.15, 1.0)
    end
    
    local padding_h = theme.space.md
    local padding_v = theme.space.sm
    local font_size = theme.font_sizes.md
    
    if size == "sm" then
        padding_h = theme.space.sm
        padding_v = theme.space.xs
        font_size = theme.font_sizes.sm
    elseif size == "lg" then
        padding_h = theme.space.lg
        padding_v = theme.space.md
        font_size = theme.font_sizes.lg
    end
    
    local patch = style.StylePatch:new()
    patch.shared = {
        backgroundColor = base_color,
        cornerRadius = style.corner_radius(theme.radii.md),
    }
    patch.border = {
        color = theme.colors.transparent,
        width = style.border_width(0),
    }
    patch.layout = {
        paddingLeft = padding_h,
        paddingRight = padding_h,
        paddingTop = padding_v,
        paddingBottom = padding_v,
    }
    
    local hover_patch = style.StylePatch:new()
    hover_patch.shared = {
        backgroundColor = hover_color,
    }
    patch.states = {
        [style.STATE_HOVER] = hover_patch,
    }
    
    return patch_with(opts, patch)
end

theme.text = {}

theme.text.body = function(opts)
    local patch = style.StylePatch:new()
    patch.textConfig = {
        textColor = theme.colors.fg_default,
        fontSize = theme.font_sizes.md,
        lineHeight = math.floor(theme.font_sizes.md * theme.line_heights.normal),
    }
    return patch_with(opts, patch)
end

theme.text.title = function(opts)
    local patch = style.StylePatch:new()
    patch.textConfig = {
        textColor = theme.colors.fg_default,
        fontSize = theme.font_sizes.xl,
        lineHeight = math.floor(theme.font_sizes.xl * theme.line_heights.snug),
    }
    return patch_with(opts, patch)
end

theme.text.button = function(opts)
    local patch = style.StylePatch:new()
    patch.textConfig = {
        textColor = theme.colors.white,
        fontSize = theme.font_sizes.md,
        lineHeight = theme.font_sizes.md,
    }
    return patch_with(opts, patch)
end

theme.text.muted = function(opts)
    local patch = style.StylePatch:new()
    patch.textConfig = {
        textColor = theme.colors.fg_muted,
        fontSize = theme.font_sizes.sm,
        lineHeight = math.floor(theme.font_sizes.sm * theme.line_heights.normal),
    }
    return patch_with(opts, patch)
end

theme.text.badge = function(opts)
    local patch = style.StylePatch:new()
    patch.textConfig = {
        textColor = theme.colors.fg_default,
        fontSize = theme.font_sizes.xs,
        lineHeight = theme.font_sizes.xs,
    }
    return patch_with(opts, patch)
end

theme.card = function(opts)
    local patch = style.StylePatch:new()
    patch.shared = {
        backgroundColor = theme.colors.white,
        cornerRadius = style.corner_radius(theme.radii.lg),
    }
    patch.border = {
        color = theme.colors.border_muted,
        width = style.border_width(1),
    }
    return patch_with(opts, patch)
end

theme.input = function(opts)
    local patch = style.StylePatch:new()
    patch.shared = {
        backgroundColor = theme.colors.white,
        cornerRadius = style.corner_radius(theme.radii.sm),
    }
    patch.border = {
        color = theme.colors.border_default,
        width = style.border_width(1),
    }
    patch.layout = {
        paddingLeft = theme.space.md,
        paddingRight = theme.space.md,
        paddingTop = theme.space.sm,
        paddingBottom = theme.space.sm,
    }
    
    return patch_with(opts, patch)
end

return theme
