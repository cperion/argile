local ui = {}

ui.Arena = struct {
    nextAllocation : uint64,
    capacity : uint64,
    memory : &int8
}

terra ui.Arena:reset()
    self.nextAllocation = 0
end

terra ui.Arena:allocate(capacity : int32, itemSize : uint32) : &opaque
    var alignedOffset = self.nextAllocation + ((64 - (self.nextAllocation % 64)) % 64)
    var totalSize = uint64(capacity) * uint64(itemSize)
    if alignedOffset + totalSize <= self.capacity then
        self.nextAllocation = alignedOffset + totalSize
        return [&opaque](self.memory + alignedOffset)
    end
    return nil
end

terra ui.CreateArenaWithCapacityAndMemory(capacity : uint64, memory : &int8) : ui.Arena
    return ui.Arena {
        nextAllocation = 0,
        capacity = capacity,
        memory = memory
    }
end

return ui
