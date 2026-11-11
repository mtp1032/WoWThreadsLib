
## WoWThreads Programmer's Reference Manual

**Terminology**
- **thread**: a 'thread' is shorthand for a *thread of execution*. Essentially an independent set of instructions having their own context (i.e., a stack, symbol table, and so forth). In WoWThreads, a thread consists is coroutine and the function it is to execute. A thread handle, a data structure (see next) containing a reference to the thread (coroutine + function).
- **thread handle**: An opaque structure containing the properties of a thread.  In WoWThreads a thread handle is implemented as a table containing the attributes of the thread. For example, here are the first 5 of 18 attributes:
```
TH_COROUTINE -- the coroutine that executes a function.
TH_COROUTINE_ARGS -- Parameters passed to the coroutine
TH_UNIQUE_ID -- a unique, numerical identifier
TH_SIGNAL_QUEUE -- a FIFO queue containing all of the thread's pending ending signals
TH_TICS_PER_YIELD_INTERVAL --The time, in frame tics, the thread suspends itself when yielding the processor. On a 60 FPS machine, this is approximately 16.67 milliseconds.
```
### Signature:
    value, errorMsg = thread:sendSignal( target_h, signalValue [,...] )
####  Description:
    Sends a signal to the specified thread. Note: a return value of true only means the signal was delivered. It does mean the signal has been seenby the target thread.
####  Parameters: 
- thread_h (handle): The thread to which the signal is to be sent. 
- signalValue (number): the signal being sent.
- ... (varargs, optional) Data (including functions) to be passed to the receiving thread.
####  Returns:
- If successful: value = true or false. A 'true' value means that...
- The signal was inserted into the target thread's signal queue. A value = false can mean one of two alternatives:
- The target thread was dead (completed or faulted). If failed: nil is returned indicating the signal was not delivered. 
####  Usage:

### Signature: 
    local signal, sender_h, ... = thread:getSignal()
####  Description:  
    The retrieval semantics of the thread's signal queue is FIFO. So, getting
    a signal means getting the first signal in the calling thread's signal 
    queue. In other words, then signal that has been in the queue the longest. 
####  Parameters:
- signal (number): 
- sender_h (thread handle): the handle of the thread that sent the signal.
- ... (varargs): any additional data associated with the signal.
####  Returns:
- Success: returns the signal value, sender handle, and any additional data.
- Failure: nil is returned, and the errorMsg parameter contains an error message.
####  Usage:
