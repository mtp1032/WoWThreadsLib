# WoWThreadsLib Versions

## 0.0.1 to 0.2.0 (In Development)
- WoWThreadsLib is an embedded form of the sharable [addon] WoWThreads development transitionng to an embedded library.

# Version 0.2.0 (Alpha)
- Usable, but still lacking thread:exit() and thread:getExitData()
- Will move to 0.3.0 when error injection testing is complete and exit and getExitDate are working.
  
# Version 0.3.0 (pre Beta)
- Added thread:exit(...) and thread:getExitData( thread_h ) to library
- Moved from a scheduler based on C_After to a frame based OnUpdate mechanism.
- Each passed test will cause a patch update. So that the lib will be moved to Version 0.4.0 (Beta). 
 # Version 0.6.0
 - Completed design and coding of signal functionality. Prelminary testing for
  semantic execution is complete. Will begin fault testing.
 # Version 0.7.0
  - Skipped this version. Found a number of bugs having to do with my use of xpcall that ended up making changes everywhere. So, I backed up to 0.6.0 and fixed the bugs in that repo.
 # Version 0.8.1
 - This version is no longer crippled by the boundary condtions of xpcall. I'll be working on the test harness that will automate all of the tests. Each test completion will be a patch upgrade. At 0.9.0 we'll enter in to performance evaluation and doc preparation.