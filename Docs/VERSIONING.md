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
