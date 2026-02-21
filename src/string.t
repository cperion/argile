local ui = {}

ui.String = struct {
    isStaticallyAllocated : bool,
    length : int32,
    chars : &int8
}

ui.StringSlice = struct {
    length : int32,
    chars : &int8,
    baseChars : &int8
}

terra ui.String:get(index : int32) : int8
    if index >= 0 and index < self.length then
        return self.chars[index]
    end
    return 0
end

terra ui.StringSlice:get(index : int32) : int8
    if index >= 0 and index < self.length then
        return self.chars[index]
    end
    return 0
end

return ui
