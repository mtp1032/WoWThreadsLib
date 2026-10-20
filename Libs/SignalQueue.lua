--=================================================================================
-- Filename: SignalQueue.lua
-- Author: Michael Peterson
-- Date: October, 2026
--=================================================================================
local ADDON_NAME, ns = ...

ns.SignalQueue = ns.SignalQueue or {}
local sigQueue = ns.SignalQueue

-- SignalQueue class definition
sigQueue.__index = sigQueue

-- Constructor
function sigQueue.new()
    local self = setmetatable({}, sigQueue)
    self.front = 1
    self.rear = 0
    self.items = {}
    return self
end

-- @brief: Adds an item to the rear of the queue
-- @param: value
-- @returns: None
function sigQueue:enqueue(value)
    self.rear = self.rear + 1
    self.items[self.rear] = value
end

-- @brief: removes an item from the front of the queue
-- @param: None
-- @returns: the removed value or nil if the queue is empty
function sigQueue:dequeue()
    if self:isEmpty() then
        return nil
    else
        local value = self.items[self.front]
        self.items[self.front] = nil  -- Optional: clear the slot
        self.front = self.front + 1
        if self.front > self.rear then  -- Reset if the queue is empty
            self.front = 1
            self.rear = 0
        end
        return value
    end
end

-- @brief: Returns the first item in the queue without removing it
-- @param: None
-- @returns: the first item in the queue or nil if the queue is empty
function sigQueue:peek()
    if self:isEmpty() then
        return nil
    else
        return self.items[self.front]
    end
end

-- @brief: Checks if the queue is empty
-- @param: None
-- @returns: true if the queue is empty, false otherwise
function sigQueue:isEmpty()
    return self.front > self.rear
end

-- @brief: Returns the number of items in the queue
-- @param: None
-- @returns: the size of the queue
function sigQueue:size()
    return self.rear - self.front + 1
end
