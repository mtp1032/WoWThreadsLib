

**Testing Strategy**

**Wrapper Functions**
A *wrapper* function is one in which or more of the public API's entry points are individually executed and tested for correct behavior.

**Naming Conventions**
In this framework these wrapper functions follow a specific naming convention, namely, all wrapper functions begin with the word "wrap." For example,

- **wrap**ThreadTestParams() -- tests verious thread functions

- **wrap**ThreadTestSchedule() -- tests that validates the library's scheduling implementtation

- **wrap**ThreadTestCongestion() -- a stress test that overloads the library.

- **wrap**SignalTestParams() -- tests the API's signal functions

- **wrap**SignalTestComms() -- tests the semantics of thread-to-thread communications.

---
**Test Modules**

A test module is nothing more than a Lua file containing one and only one wrapper function. For example, the module containing the *wrapTestThreadParams*() wrapper, is named *wrapTestThreadParams.lua*. Similarly, the file containing the *wrapTestSignalParams()* is named *TestSignalParams.lua*

Each wrapper function constitutes a single test. However, the wrapper contains the actual code being tested. Here's what the wrapper for testing the validity of the function parameters of thread:create():

```
local function wrapTestThreadParams()
    local ticks = 30

    --=======================
    -- Test For Invalid types
    --=======================
    local test_h, errorMsg = thread:create("ticks", dummy)
    if test_h ~= nil then
        error(string.format("%s Test Result FAIL:", uils:dbgPrefix() ))
    end

    post:message( string.format("Thread wrapTestThreadParams() completed."))
end
```
In the wrapper function above, only the test for a invalid *ticks* is shown. In reality, this particular wrapper executes three(3) additional tests even though the thread:create() service has only two(2) parameters that can be tested. In practice, the wrapper passes if all of the sub-tests pass.

**Test Startup: Control Flow**
<To Be Supplied>
