program trans_time

!----------------------------------------------------------------------
! purpose: interface between CAM and WRF time and date
!
! method: Read DART 'state vector' file (proprietary format).
!         Reform time and date into form needed by WRF.
!         Write out WRF time and date to wrfinput file.
!
! Note: This needs to be done BEFORE update_wrf_bc
!
! author: Kevin Raeder 8/1/03
! mods for WRF: Josh Hacker 4/16/03
!
!----------------------------------------------------------------------


use time_manager_mod, only : time_type, read_time, write_time, &
                             get_time, set_time, operator(-), get_date, &
                             print_time, set_date, operator (+), &
                             set_calendar_type, NO_CALENDAR, NOLEAP, &
                             GREGORIAN
use assim_model_mod, only : static_init_assim_model, binary_restart_files

use model_mod, only: get_wrf_date, set_wrf_date, output_wrf_time


use utilities_mod, only : get_unit

implicit none

integer               :: ntimes = 2, n, nhtfrq, &
                         calendar_type = GREGORIAN
integer               :: file_unit, seconds, days, &
                         year, month, day, hour, minute, second, &
                         cam_date, cam_tod
type(time_type)       :: dart_time(2), forecast_length, wrf_time
character (len = 128) :: file_name = 'dart_wrf_vector'
character (len = 16)  :: file_form

call set_calendar_type(calendar_type)

! Static init assim model calls static_init_model
call static_init_assim_model()

! get form of file output from assim_model_mod
if (binary_restart_files == .true.) then
   file_form = 'unformatted'
else
   file_form = 'formatted'
endif
file_unit = get_unit()

open(unit = file_unit, file = file_name, form=file_form)
! end time is first, then beginning time
!  -namelist "&camexp START_YMD=$times[3] START_TOD=$times[4] \
!                     STOP_YMD=$times[1] STOP_TOD=$times[2] NHTFRQ=$times[5] /" \

! this should be the init time
call get_wrf_date(year, month, day, hour, minute, second)
wrf_time = set_date(year, month, day, hour, minute, second)
dart_time(1) = read_time(file_unit, file_form)
call print_time(dart_time(1))
dart_time(2) = read_time(file_unit, file_form)

! the current time is in 2, and the next time is in 1, so increment to 2
wrf_time = dart_time(2) + wrf_time

! get new date
call get_date(wrf_time, year, month, day, hour, minute, second)

! put new date into the wrf construct
call set_wrf_date(year, month, day, hour, minute, second)

! tag the wrfinput file with the new date.
call output_wrf_time()

close(file_unit)

end program trans_time

