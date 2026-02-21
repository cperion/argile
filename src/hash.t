local ui = require("src.string")

ui.ElementId = struct {
    id : uint32,
    offset : uint32,
    baseId : uint32,
    stringId : ui.String
}

terra ui.HashData(data : &uint8, length : uint64) : uint64
    var hash : uint64 = 0
    var i : uint64 = 0
    while i < length do
        hash = hash + data[i]
        hash = hash + (hash << 10)
        hash = hash ^ (hash >> 6)
        i = i + 1
    end
    return hash
end

terra ui.HashNumber(offset : uint32, seed : uint32) : ui.ElementId
    var hash = seed
    hash = hash + (offset + 48)
    hash = hash + (hash << 10)
    hash = hash ^ (hash >> 6)
    
    hash = hash + (hash << 3)
    hash = hash ^ (hash >> 11)
    hash = hash + (hash << 15)
    
    var result : ui.ElementId
    result.id = hash + 1
    result.offset = offset
    result.baseId = seed
    result.stringId.isStaticallyAllocated = false
    result.stringId.length = 0
    result.stringId.chars = nil
    return result
end

terra ui.HashString(key : ui.String, seed : uint32) : ui.ElementId
    var hash = seed
    
    for i = 0, key.length do
        hash = hash + [uint32](key.chars[i])
        hash = hash + (hash << 10)
        hash = hash ^ (hash >> 6)
    end
    
    hash = hash + (hash << 3)
    hash = hash ^ (hash >> 11)
    hash = hash + (hash << 15)
    
    var result : ui.ElementId
    result.id = hash + 1
    result.offset = 0
    result.baseId = hash + 1
    result.stringId = key
    return result
end

terra ui.HashStringWithOffset(key : ui.String, offset : uint32, seed : uint32) : ui.ElementId
    var hash : uint32 = 0
    var base = seed
    
    for i = 0, key.length do
        base = base + [uint32](key.chars[i])
        base = base + (base << 10)
        base = base ^ (base >> 6)
    end
    
    hash = base
    hash = hash + offset
    hash = hash + (hash << 10)
    hash = hash ^ (hash >> 6)
    
    hash = hash + (hash << 3)
    base = base + (base << 3)
    hash = hash ^ (hash >> 11)
    base = base ^ (base >> 11)
    hash = hash + (hash << 15)
    base = base + (base << 15)
    
    var result : ui.ElementId
    result.id = hash + 1
    result.offset = offset
    result.baseId = base + 1
    result.stringId = key
    return result
end

return ui
