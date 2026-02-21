local ui = require("src.arena")

ui.Array = terralib.memoize(function(T)
    local ArrayT = struct {
        capacity : int32,
        length : int32,
        internalArray : &T
    }
    
    terra ArrayT:allocate(capacity : int32, arena : &ui.Arena) : bool
        if capacity <= 0 then
            self.capacity = 0
            self.length = 0
            self.internalArray = nil
            return false
        end
        var mem = arena:allocate(capacity, [uint32](sizeof(T)))
        if mem == nil then
            self.capacity = 0
            self.length = 0
            self.internalArray = nil
            return false
        end
        self.capacity = capacity
        self.length = 0
        self.internalArray = [&T](mem)
        return true
    end
    ArrayT.methods.allocate:setinlined(true)
    
    terra ArrayT:add(item : T) : &T
        if self.length < self.capacity then
            var ptr = &self.internalArray[self.length]
            @ptr = item
            self.length = self.length + 1
            return ptr
        end
        return nil
    end
    ArrayT.methods.add:setinlined(true)
    
    terra ArrayT:get(index : int32) : &T
        if index >= 0 and index < self.length then
            return &self.internalArray[index]
        end
        return nil
    end
    ArrayT.methods.get:setinlined(true)
    
    terra ArrayT:getValue(index : int32) : T
        if index >= 0 and index < self.length then
            return self.internalArray[index]
        end
        var empty : T
        return empty
    end
    ArrayT.methods.getValue:setinlined(true)
    
    terra ArrayT:set(index : int32, value : T)
        if index >= 0 and index < self.capacity then
            self.internalArray[index] = value
            if index >= self.length then
                self.length = index + 1
            end
        end
    end
    ArrayT.methods.set:setinlined(true)
    
    terra ArrayT:removeSwapback(index : int32) : T
        if index >= 0 and index < self.length then
            self.length = self.length - 1
            var removed = self.internalArray[index]
            self.internalArray[index] = self.internalArray[self.length]
            return removed
        end
        var empty : T
        return empty
    end
    ArrayT.methods.removeSwapback:setinlined(true)
    
    terra ArrayT:clear()
        self.length = 0
    end
    ArrayT.methods.clear:setinlined(true)
    
    return ArrayT
end)

ui.Slice = terralib.memoize(function(T)
    local SliceT = struct {
        length : int32,
        internalArray : &T
    }
    
    terra SliceT:get(index : int32) : &T
        if index >= 0 and index < self.length then
            return &self.internalArray[index]
        end
        return nil
    end
    SliceT.methods.get:setinlined(true)
    
    terra SliceT:getValue(index : int32) : T
        if index >= 0 and index < self.length then
            return self.internalArray[index]
        end
        var empty : T
        return empty
    end
    SliceT.methods.getValue:setinlined(true)
    
    return SliceT
end)

return ui
