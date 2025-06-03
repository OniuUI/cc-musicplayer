-- Theme system for Bognesferga Radio
-- Centralizes all color schemes and styling definitions

local themes = {}

-- Main theme configuration
themes.default = {
    -- Branding
    branding = {
        title = "Bognesferga Radio",
        developer = "Developed by Forty",
        rainbow_colors = {colors.red, colors.orange, colors.yellow, colors.lime, colors.cyan, colors.lightBlue, colors.purple, colors.magenta}
    },
    
    -- Main interface colors
    colors = {
        -- Background colors
        background = colors.black,
        header_bg = colors.blue,
        footer_bg = colors.gray,
        
        -- Tab colors
        tab_active = colors.white,
        tab_inactive = colors.lightGray,
        tab_bg = colors.blue,
        
        -- Text colors
        text_primary = colors.white,
        text_secondary = colors.lightGray,
        text_disabled = colors.gray,
        text_accent = colors.yellow,
        text_success = colors.lime,
        text_error = colors.red,
        
        -- Interactive elements
        button = colors.lightBlue,
        button_active = colors.cyan,
        button_hover = colors.blue,
        search_box = colors.lightGray,
        
        -- Status colors
        playing = colors.lime,
        loading = colors.yellow,
        error = colors.red,
        
        -- Volume slider
        volume_bg = colors.gray,
        volume_fill = colors.cyan,
        volume_text = colors.white
    },
    
    -- UI layout constants
    layout = {
        header_height = 1,
        tab_height = 1,
        footer_height = 1,
        button_padding = 1,
        min_button_width = 8
    }
}

-- Get current theme
function themes.getCurrent()
    return themes.default
end

-- Get theme colors
function themes.getColors()
    return themes.getCurrent().colors
end

-- Get branding info
function themes.getBranding()
    return themes.getCurrent().branding
end

-- Get layout constants
function themes.getLayout()
    return themes.getCurrent().layout
end

return themes 