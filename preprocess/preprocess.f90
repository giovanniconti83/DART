! DART software - Copyright 2004 - 2013 UCAR. This open source software is
! provided by UCAR, "as is", without charge, subject to all terms of use at
! http://www.image.ucar.edu/DAReS/DART/DART_download
!
! $Id$

program preprocess

! Takes a list of observation type module path names. These modules contain
! multiple fragments of standard F90 that may be required to implement forward
! observation operators for DART. The sections are retrieved from the files
! by this program and inserted into the appropriate blanks in the
! DEFAULT_obs_def_mod.F90 and DEFAULT_obs_kind_mod.F90 templates. 
! The final obs_def_mod.f90 and obs_kind_mod.f90 that are created contain
! the default code plus all the code required from the selected observation
! type modules. Preprocess also inserts the required identifier and string
! for the corresponding observation kinds (and only those kinds).

! NEED TO ADD IN ALL THE ERROR STUFF

use     types_mod, only : r8
use utilities_mod, only : register_module, error_handler, E_ERR, E_MSG,   &
                          file_exist, open_file, logfileunit, &
                          initialize_utilities, do_nml_file, do_nml_term, &
                          find_namelist_in_file, check_namelist_read,     &
                          finalize_utilities

implicit none

! version controlled file description for error handling, do not edit
character(len=256), parameter :: source   = &
   "$URL$"
character(len=32 ), parameter :: revision = "$Revision$"
character(len=128), parameter :: revdate  = "$Date$"

! Pick something ridiculously large and forget about it (lazy)
integer, parameter   :: max_types = 5000, max_kinds = 5000
character(len = 256) :: line, test, test2, type_string(max_types), &
                        kind_string(max_kinds), t_string, temp_type, temp_kind
integer              :: iunit, ierr, io, i, j, k
integer              :: l_string, l2_string, total_len, linenum
integer              :: num_types_found, num_kinds_found, kind_index(max_types)
logical              :: duplicate, usercode(max_types), temp_user
character(len = 169) :: err_string

! specific marker strings
character(len = 33) :: kind_start_string = '! BEGIN DART PREPROCESS KIND LIST'
character(len = 31) :: kind_end_string   = '! END DART PREPROCESS KIND LIST'
! these are intended to be used in the revisions for the next major release,
! but are currently unused.  right now we are going to continue to have a fixed
! kinds table in the DEFAULT_obs_kind_mod.F90 file, but eventually it should
! be autogenerated and these strings will enclose kinds which should be
! defined, without mapping any particular observation type to them.  this
! code could be in either the obs_def_*_mod.f90 files or in the model_mods.
!character(len = 35) :: kind2_start_string = '! BEGIN DART PREPROCESS USED KINDS'
!character(len = 33) :: kind2_end_string   = '! END DART PREPROCESS USED KINDS'

! output format decorations
character(len = 78) :: separator_line = &
'!---------------------------------------------------------------------------'
character(len = 78) :: blank_line = &
'                                                                            '
!! currently unused, but available if wanted:
!character(len = 12) :: start_line = '!  Start of '
!character(len = 12) :: end_line =   '!  End of   '
!character(len = 78) :: blank_comment_line = &
!'!                                                                           '

! List of the DART PREPROCESS strings for obs_def type files.
character(len = 29) :: preprocess_string(8) = (/ &
      'MODULE CODE                  ', &
      'USE FOR OBS_KIND_MOD         ', &
      'USE OF SPECIAL OBS_DEF MODULE', &
      'GET_EXPECTED_OBS_FROM_DEF    ', &
      'READ_OBS_DEF                 ', &
      'WRITE_OBS_DEF                ', &
      'INTERACTIVE_OBS_DEF          ', &
      'THE EIGHTH ONE IS UNDEFINED  '/)

!! Must match the list above.  Is there a default code section that we can
!! autogenerate for this section?
!logical :: default_code(8) = &
!   (/ .false., &
!      .false., &
!      .false., &
!      .true.,  &
!      .true.,  &
!      .true.,  &
!      .true.,  &
!      .false. /)

integer, parameter :: module_item = 1
integer, parameter :: kind_item = 2
integer, parameter :: use_item = 3
integer, parameter :: get_expected_item = 4
integer, parameter :: read_item = 5
integer, parameter :: write_item = 6
integer, parameter :: interactive_item = 7

integer :: num_input_files = 0
integer :: num_model_files = 0
integer :: obs_def_in_unit, obs_def_out_unit
integer :: obs_kind_in_unit, obs_kind_out_unit, in_unit

integer, parameter   :: max_input_files = 1000
integer, parameter   :: max_model_files = 1000
logical :: file_has_usercode(max_input_files) = .false.

! The namelist reads in a sequence of path_names that are absolute or
! relative to the working directory in which preprocess is being executed
! and these files are used to fill in observation kind details in
! DEFAULT_obs_def_mod.f90 and DEFAULT_obs_kind_mod.f90.
character(len = 129) :: input_obs_def_mod_file = &
                        '../../../obs_def/DEFAULT_obs_def_mod.F90'
character(len = 129) :: output_obs_def_mod_file = &
                        '../../../obs_def/obs_def_mod.f90'
character(len = 129) :: input_obs_kind_mod_file = &
                        '../../../obs_kind/DEFAULT_obs_kind_mod.F90'
character(len = 129) :: output_obs_kind_mod_file = &
                        '../../../obs_kind/obs_kind_mod.f90'
character(len = 129) :: input_files(max_input_files) = 'null'
character(len = 129) :: model_files(max_model_files) = 'null'
logical              :: overwrite_output = .true.

namelist /preprocess_nml/ input_obs_def_mod_file, input_obs_kind_mod_file,   &
                          output_obs_def_mod_file, output_obs_kind_mod_file, &
                          input_files, model_files, overwrite_output

!---------------------------------------------------------------------------
! start of program code

!Begin by reading the namelist
call initialize_utilities('preprocess')
call register_module(source, revision, revdate)

! Read the namelist entry
call find_namelist_in_file("input.nml", "preprocess_nml", iunit)
read(iunit, nml = preprocess_nml, iostat = io)
call check_namelist_read(iunit, io, "preprocess_nml")

! Output the namelist file information
write(logfileunit, *) 'Path names of default obs_def and obs_kind modules'
write(logfileunit, *) trim(input_obs_def_mod_file)
write(logfileunit, *) trim(input_obs_kind_mod_file)
write(*, *) 'Path names of default obs_def and obs_kind modules'
write(*, *) trim(input_obs_def_mod_file)
write(*, *) trim(input_obs_kind_mod_file)

write(logfileunit, *) 'Path names of output obs_def and obs_kind modules'
write(logfileunit, *) trim(output_obs_def_mod_file)
write(logfileunit, *) trim(output_obs_kind_mod_file)
write(*, *) 'Path names of output obs_def and obs_kind modules'
write(*, *) trim(output_obs_def_mod_file)
write(*, *) trim(output_obs_kind_mod_file)

! A path for the default files is required. Have an error if these are null.
if(input_obs_def_mod_file == 'null') &
   call error_handler(E_ERR, 'preprocess', &
      'Namelist must provide input_obs_def_mod_file', &
      source, revision, revdate)
if(input_obs_kind_mod_file == 'null') &
   call error_handler(E_ERR, 'preprocess', &
      'Namelist must provide input_obs_kind_mod_file', &
      source, revision, revdate)

! A path for the output files is required. Have an error if these are null.
if(output_obs_def_mod_file == 'null') &
   call error_handler(E_ERR, 'preprocess', &
      'Namelist must provide output_obs_def_mod_file', &
      source, revision, revdate)
if(output_obs_kind_mod_file == 'null') &
   call error_handler(E_ERR, 'preprocess', &
      'Namelist must provide output_obs_kind_mod_file', &
      source, revision, revdate)

write(logfileunit, *) 'INPUT obs_def files follow:'
write(*, *) 'INPUT obs_def files follow:'

do i = 1, max_input_files
   if(input_files(i) == 'null') exit
   write(logfileunit, *) trim(input_files(i))
   write(*, *) trim(input_files(i))
   num_input_files= i
end do

write(logfileunit, *) 'INPUT model files follow:'
write(*, *) 'INPUT model files follow:'

do i = 1, max_model_files
   if(model_files(i) == 'null') exit
   write(logfileunit, *) trim(model_files(i))
   write(*, *) trim(model_files(i))
   num_model_files = i
end do

! Try to open the DEFAULT and OUTPUT files
! DEFAULT files must exist or else an error
if(file_exist(trim(input_obs_def_mod_file))) then
   ! Open the file for reading
   obs_def_in_unit = open_file(input_obs_def_mod_file, action='read')
else
   ! If file does not exist it is an error
   write(err_string, *) 'file ', trim(input_obs_def_mod_file), &
      ' must exist (and does not)'
   call error_handler(E_ERR, 'preprocess', err_string, &
      source, revision, revdate)
endif

if(file_exist(trim(input_obs_kind_mod_file))) then
   ! Open the file for reading
   obs_kind_in_unit = open_file(input_obs_kind_mod_file, action='read')
else
   ! If file does not exist it is an error
   write(err_string, *) 'file ', trim(input_obs_kind_mod_file), &
      ' must exist (and does not)'
   call error_handler(E_ERR, 'preprocess', err_string, &
      source, revision, revdate)
endif

! Error if Output files EXIST, unless 'overwrite_output' is TRUE
if(.not. file_exist(trim(output_obs_def_mod_file)) .or. overwrite_output) then
   ! Open (create) the file for writing
   obs_def_out_unit = open_file(output_obs_def_mod_file, action='write')
else
   ! If file *does* exist and we haven't said ok to overwrite, error
   write(err_string, *) 'file ', trim(output_obs_def_mod_file), &
      ' exists and will not be overwritten: Please remove or rename'
   call error_handler(E_ERR, 'preprocess', err_string, &
      source, revision, revdate)
endif

if(.not. file_exist(trim(output_obs_kind_mod_file)) .or. overwrite_output) then
   ! Open (create) the file for writing
   obs_kind_out_unit = open_file(output_obs_kind_mod_file, action='write')
else
   ! If file *does* exist and we haven't said ok to overwrite, error
   write(err_string, *) 'file ', trim(output_obs_kind_mod_file), &
      ' exists and will not be overwritten: Please remove or rename'
   call error_handler(E_ERR, 'preprocess', err_string, &
      source, revision, revdate)
endif

!______________________________________________________________________________
! Preprocessing for the obs_kind module
! Get all the type/kind strings from all of the obs_def files 
! up front and then insert stuff.  Easier to error check and combine
! duplicate kinds.

! Initial number of types and kinds is 0
num_types_found = 0
num_kinds_found = 0

SEARCH_INPUT_FILES: do j = 1, num_input_files
   if(file_exist(trim(input_files(j)))) then
      ! Open the file for reading
         in_unit = open_file(input_files(j), action='read')
   else
      ! If file does not exist it is an error
      write(err_string, *) 'input_files ', trim(input_files(j)), &
         ' does NOT exist (and must).'
      call error_handler(E_ERR, 'preprocess', err_string, &
         source, revision, revdate)
   endif

   ! Read until the ! BEGIN KIND LIST is found
   linenum = 0
   FIND_KIND_LIST: do

      read(in_unit, 222, IOSTAT = ierr) line
      ! If end of file, input file is incomplete or weird stuff happened
      if(ierr /= 0) then
         write(err_string, *) 'file ', trim(input_files(j)), &
            ' does NOT contain ', kind_start_string
         call error_handler(E_ERR, 'preprocess', err_string, &
            source, revision, revdate)
      endif
      linenum = linenum + 1

      ! Look for the ! BEGIN KIND LIST in the current line
      test = adjustl(line)
      if(test(1:33) == kind_start_string) exit FIND_KIND_LIST
   end do FIND_KIND_LIST

   ! Subsequent lines contain the type_identifier (same as type_string), and
   ! kind_string separated by commas, and optional usercode flag
   EXTRACT_KINDS: do
      read(in_unit, 222, IOSTAT = ierr) line
      ! If end of file, input file is incomplete or weird stuff happened
      if(ierr /= 0) then
         write(err_string, *) 'file ', trim(input_files(j)), &
            ' does NOT contain ', kind_end_string
         call error_handler(E_ERR, 'preprocess', err_string, &
            source, revision, revdate)
      endif
      linenum = linenum + 1

      ! Look for the ! END KIND LIST in the current line
      test = adjustl(line)
      if(test(1:31) == kind_end_string) exit EXTRACT_KINDS

      ! All lines between start/end must be type/kind lines.
      ! Format:  ! type_string, kind_string [, COMMON_CODE]

      ! Get rid of the leading comment and any subsequent whitespace
      if (line(1:1) /= '!') then 
         err_string = 'line must begin with !'
         call typekind_error(err_string, line, input_files(j), linenum)
      endif

      test = adjustl(line(2:))
      total_len = len(test)

      ! Compute the length of the type_string by seeking comma
      do k = 1, total_len
         l_string = k - 1
         if(test(k:k) == ',') exit
      end do

      ! comma not found? (first one is required)
      if (l_string == total_len - 1) then
         err_string = 'strings must be separated by commas'
         call typekind_error(err_string, line, input_files(j), linenum)
      endif

      ! save results in temp vars for now, so we can check for
      ! duplicates (not allowed in types) or duplicates (which are
      ! expected in kinds)
      temp_type = adjustl(test(1:l_string))

      ! check for another comma before end of line (not mandatory)
      do k = l_string+2, total_len
         l2_string = k - 1
         if(test(k:k) == ',') exit
      end do

      ! not found?  ok, then kind is remaining part of string
      if (l2_string == total_len - 1) then
         temp_kind = adjustl(test(l_string + 2:))
         temp_user = .true.
      else
         ! another comma found, need to have COMMON_CODE on rest of line
         test2 = adjustl(test(l2_string+2:))
         if (test2(1:11) /= 'COMMON_CODE') then
            err_string = 'if third word present on line, it must be COMMON_CODE'
            call typekind_error(err_string, line, input_files(j), linenum)
         endif

         temp_kind = adjustl(test(l_string + 2:l2_string))
         temp_user = .false.
         
      endif

      if (temp_user) file_has_usercode(j) = .true.

!FIXME: does not correctly flag: !type kind, COMMON_CODE 
! as an error (note missing comma between type and kind)
! how to catch?  not allow spaces in type?
  
      ! Another type/kind line; increment the type count.  Check the kinds
      ! list for repeated occurances first before deciding this is a new kind.

      ! first implementation, do not allow repeated types
      ! we could allow them if the kinds match and there is no usercode
      ! in either the original definition nor in this one
      do i=1, num_types_found
         if (trim(type_string(i)) == trim(temp_type)) then
            ! FIXME: could allow dups if 1) same kind 2) no usercode
            ! but the error messages to the user will be complex to really
            ! explain what is going on here.
       
            if ((trim(kind_string(kind_index(i))) /= trim(temp_kind)) .or. &
                (temp_user) .or. (usercode(i))) then
               err_string = &
                  'Duplicate! This observation type has already been processed'
               call typekind_error(err_string, line, input_files(j), linenum)
            else ! dup, can safely ignore?
               cycle EXTRACT_KINDS
            endif
         endif
      end do

      num_types_found = num_types_found + 1
      type_string(num_types_found) = temp_type

      ! repeated strings are ok for kinds.
      ! this loop adds a new kind to the string array if it has not already
      ! been seen, and then sets up two arrays which are one-to-one with the
      ! number of types:  what kind index number this type maps to, and
      ! whether this type has user-supplied interpolation code or not.
      duplicate = .false.
      do i=1, num_kinds_found
         if (trim(kind_string(i)) == trim(temp_kind)) then
            duplicate = .true.
            kind_index(num_types_found) = i
            usercode(num_types_found) = temp_user
            exit
         endif
      end do
      if (.not. duplicate) then
         num_kinds_found = num_kinds_found + 1
         kind_string(num_kinds_found) = temp_kind
         kind_index(num_types_found) = num_kinds_found
         usercode(num_types_found) = temp_user
      endif

   end do EXTRACT_KINDS

   ! Close this obs_kind file
   close(in_unit)
end do SEARCH_INPUT_FILES

! Copy over lines up to the next insertion point
do
   read(obs_kind_in_unit, 222, IOSTAT = ierr) line
   ! Check for end of file
   if(ierr /=0) then
      call error_handler(E_ERR, 'preprocess', &
         'Input DEFAULT obs_kind file ended unexpectedly', &
         source, revision, revdate)
   endif

   ! Is this the place to start writing preprocessor stuff
   test = adjustl(line)
   if(test(1:51) == '! DART PREPROCESS INTEGER DECLARATION INSERTED HERE') exit

   ! Write the line to the output file
   write(obs_kind_out_unit, 21) trim(line)
end do

! THIS TABLE IS CURRENTLY HARDCODED IN THE TEMPLATE, SO THE FOLLOWING LINES
! ARE COMMENTED OUT.  WHEN THE TABLE IS TO BE AUTOGENERATED AGAIN, COMMENT
! THEM BACK IN.
!! Write out the integer declaration lines for kinds
!write(obs_kind_out_unit, 51) separator_line
!write(obs_kind_out_unit, 51) blank_line
!write(obs_kind_out_unit, 51) '! Integer definitions for DART KINDS'
!write(line, *) 'integer, parameter, public :: &'
!write(obs_kind_out_unit, 51) trim(adjustl(line))
!do i = 1, num_kinds_found - 1
!   write(obs_kind_out_unit, '(A60,A3,I5,A3)') &
!      trim(kind_string(i)), ' = ', i, ', &'
!end do
!write(obs_kind_out_unit, '(A60,A3,I5)') &
!   trim(kind_string(num_kinds_found)), ' = ', num_kinds_found
!write(obs_kind_out_unit, 51) blank_line

! Write out the integer declaration lines for types
51 format(A)
61 format(A,I5)
write(obs_kind_out_unit, 51) separator_line
write(obs_kind_out_unit, 51) blank_line
write(obs_kind_out_unit, 51) '! Integer definitions for DART TYPES'
write(line, *) 'integer, parameter, public :: & '
write(obs_kind_out_unit, 51) trim(adjustl(line))
do i = 1, num_types_found - 1
   write(obs_kind_out_unit, '(A50,A3,I5,A3)') &
      trim(type_string(i)), ' = ', i, ', & '
end do
write(obs_kind_out_unit, '(A50,A3,I5)') &
   trim(type_string(num_types_found)), ' = ', num_types_found
write(obs_kind_out_unit, 51) blank_line

! Write out the max_obs_types, too
! FIXME:  this should be max_obs_types, but it is a public and all the
! subroutines use kind where it means type.  sigh.
write(obs_kind_out_unit, 51) blank_line
write(line, 61) 'integer, parameter, public :: max_obs_kinds = ', &
   num_types_found
write(obs_kind_out_unit, 51) trim(line)
write(obs_kind_out_unit, 51) blank_line
write(obs_kind_out_unit, 51) separator_line

! Copy over lines up to the next insertion point
do
   read(obs_kind_in_unit, 222, IOSTAT = ierr) line
   ! Check for end of file
   if(ierr /=0) then
      call error_handler(E_ERR, 'preprocess', &
         'Input DEFAULT obs_kind file ended unexpectedly', &
         source, revision, revdate)
   endif

   ! Is this the place to start writing preprocessor stuff
   test = adjustl(line)
   if(test(1:51) == '! DART PREPROCESS OBS_KIND_INFO INSERTED HERE') exit

   ! Write the line to the output file
   write(obs_kind_out_unit, 21) trim(line)
end do

! Write out the definitions of each entry of obs_type_info
do i = 1, num_types_found
   write(line, '(A,I5,3A)') 'obs_type_info(', i, ') = obs_type_type(', &
      trim(type_string(i)), ", & "
   write(obs_kind_out_unit, 21) trim(line)
   write(line, *) '   ', "'", trim(type_string(i)), "', ", &
      trim(kind_string(kind_index(i))), ', .false., .false.)'
   write(obs_kind_out_unit, 21) trim(line)
end do


! Copy over rest of lines
do
   read(obs_kind_in_unit, 222, IOSTAT = ierr) line
   ! Check for end of file
   if(ierr /=0) exit

   ! Write the line to the output file
   write(obs_kind_out_unit, 21) trim(line)
end do

close(obs_kind_out_unit)
!______________________________________________________________________________

!______________________________________________________________________________
! Now do the obs_def files
! Read DEFAULT file line by line and copy into output file until
! Each insertion point is found. At the insertion points, copy the
! appropriate code from each requested obs_def file into the output obs_def
! file and then proceed.

! There are seven special code sections (ITEMS) in the obs_def file at present.
! Each copies code in from the special type specific obs_kind modules
! Loop goes to N+1 so that lines after the last item are copied to the output.
ITEMS: do i = 1, 8
   READ_LINE: do
      read(obs_def_in_unit, 222, IOSTAT = ierr) line
      222 format(A256)

      ! Check for end of file (it's an error if this is before the 
      ! 7 DART ITEMS have been passed)
      if(ierr /= 0) then
         if(i < 8) then
            call error_handler(E_ERR, 'preprocess', &
               'Input DEFAULT obs_def file ended unexpectedly', &
               source, revision, revdate)
         else
            exit ITEMS
         endif
      endif

      ! Check to see if this line indicates the start of an insertion section
      test = adjustl(line)
      t_string = '! DART PREPROCESS ' // trim(preprocess_string(i)) // ' INSERTED HERE'
      if(trim(test) == trim(t_string)) exit READ_LINE

      ! Write this line into the output file
      write(obs_def_out_unit, 21) trim(line)
      21 format(A)

   end do READ_LINE

   ! The 'USE FOR OBS_KIND_MOD' section is handled differently; lines are not
   ! copied, they are generated based on the list of types and kinds.
   if(i == kind_item) then
      ! Create use statements for both the KIND_ kinds and the individual
      ! observation type strings.
      write(obs_def_out_unit, 21) separator_line
      write(obs_def_out_unit, 21) blank_line
      do k = 1, num_types_found
         write(obs_def_out_unit, 21) &
            'use obs_kind_mod, only : ' // trim(type_string(k))
      end do
      write(obs_def_out_unit, 21) blank_line
      do k = 1, num_kinds_found
         write(obs_def_out_unit, 21) &
            'use obs_kind_mod, only : ' // trim(kind_string(k))
      end do
      write(obs_def_out_unit, 21) blank_line
      write(obs_def_out_unit, 21) separator_line
      write(obs_def_out_unit, 21) blank_line
      cycle
   endif


   ! Insert the code for this ITEM from each requested obs_def 'modules'
   do j = 1, num_input_files
      if (.not. file_has_usercode(j)) then
         if (i == module_item) then
            write(obs_def_out_unit, 51) separator_line
            write(obs_def_out_unit, 31) &
               '!No module code needed for ', &
               trim(input_files(j))
            write(obs_def_out_unit, 51) separator_line
         endif
         !if (i == use_item) then
         !   write(obs_def_out_unit, 51) separator_line
         !   write(obs_def_out_unit, 31) &
         !      '!No use statements needed for ', &
         !      trim(input_files(j))
         !   write(obs_def_out_unit, 51) separator_line
         !endif
         cycle
      endif

      ! Since there might someday be a lot of these, 
      ! open and close them each time needed
      if(file_exist(trim(input_files(j)))) then
         ! Open the file for reading
         in_unit = open_file(input_files(j), action='read')
      else
         ! If file does not exist it is an error
         write(err_string, *) 'input_files ', trim(input_files(j)), &
            ' does NOT exist.'
         call error_handler(E_ERR, 'preprocess', err_string, &
            source, revision, revdate)
      endif

      ! Read until the appropriate ITEM # label is found in the input 
      ! for this obs_type
      FIND_ITEM: do

         read(in_unit, 222, IOSTAT = ierr) line
         ! If end of file, input file is incomplete or weird stuff happened
         if(ierr /=0) then
            write(err_string, *) 'file ', trim(input_files(j)), &
               ' does NOT contain ! BEGIN DART PREPROCESS ', &
               trim(preprocess_string(i))
            call error_handler(E_ERR, 'preprocess', err_string, &
               source, revision, revdate)
         endif

         ! Look for the ITEM flag
         test = adjustl(line)
         t_string = '! BEGIN DART PREPROCESS ' // trim(preprocess_string(i))
         if(trim(test) == trim(t_string)) exit FIND_ITEM

      end do FIND_ITEM
      
      ! decoration or visual separation, depending on your viewpoint
      if (i == module_item) then
         write(obs_def_out_unit, 51) separator_line
         write(obs_def_out_unit, 31) '! Start of code inserted from ', &
            trim(input_files(j))
         write(obs_def_out_unit, 51) separator_line
         write(obs_def_out_unit, 51) blank_line
         31 format(2A)
      endif

      ! Copy all code until the end of item into the output obs_def file
      COPY_ITEM: do
         read(in_unit, 222, IOSTAT = ierr) line
         ! If end of file, input file is incomplete or weird stuff happened
         if(ierr /=0) then
            write(err_string, *) 'file ', trim(input_files(j)), &
               ' does NOT contain ! END DART PREPROCESS ', &
               trim(preprocess_string(i))
            call error_handler(E_ERR, 'preprocess', err_string, &
               source, revision, revdate)
         endif

         ! Look for the ITEM flag
         test = adjustl(line)
         t_string = '! END DART PREPROCESS ' // trim(preprocess_string(i))
         if(trim(test) == trim(t_string)) exit COPY_ITEM

         ! Write the line to the output obs_def_mod.f90 file
         ! Module code, if present, is copied verbatim.  
         ! All other code sections are preceeded by a ! in col 1
         ! so it must be stripped off.
         if (i == module_item) then
            write(obs_def_out_unit, 21) trim(line)
         else
            write(obs_def_out_unit, 21) trim(line(2:))
         endif
      end do COPY_ITEM

      ! decoration or visual separation, depending on your viewpoint
      if (i == module_item) then
         write(obs_def_out_unit, 51) blank_line
         write(obs_def_out_unit, 51) separator_line
         write(obs_def_out_unit, 31) '! End of code inserted from ', &
            trim(input_files(j))
         write(obs_def_out_unit, 51) separator_line
      endif

      ! Got everything from this file, move along
      close(in_unit)
  end do
   
  ! Now check to see if this item has any types which are expecting us
  ! to automatically generate the code for them.
  do j = 1, num_types_found
     if (usercode(j)) cycle

     select case (i)
     case (get_expected_item)
        11 format(3A)
        write(obs_def_out_unit, 11) '      case(', trim(type_string(j)), ')'
        write(obs_def_out_unit, 11) '         call interpolate_distrib(location, ', &
           trim(kind_string(kind_index(j))), ', istatus, expected_obs, state_ens_handle, win)'
     case (read_item, write_item, interactive_item)
        write(obs_def_out_unit, 11) '   case(', trim(type_string(j)), ')'
        write(obs_def_out_unit, 21) '      continue'
     case default
       ! nothing to do for others 
     end select
  end do

end do ITEMS

close(obs_def_out_unit)

call error_handler(E_MSG,'preprocess','Finished successfully.',source,revision,revdate)
call finalize_utilities('preprocess')

!------------------------------------------------------------------------------

contains

subroutine typekind_error(errtext, line, file, linenum)
 character(len=*), intent(in) :: errtext, line, file
 integer, intent(in) :: linenum

call error_handler(E_MSG, 'preprocess error:', &
   'obs_def file has bad Type/Kind line')
call error_handler(E_MSG, 'preprocess error:', errtext)
call error_handler(E_MSG, 'expected input:', &
   '! UniqueSpecificType, GenericKind   or  ! Type, Kind, COMMON_CODE')
write(err_string, '(2A,I5)') trim(file), ", line number", linenum
call error_handler(E_MSG, 'bad file:', err_string)
call error_handler(E_MSG, 'bad line contents:', line)
write(err_string, *) 'See msg lines above for error details'
call error_handler(E_ERR, 'preprocess', err_string, source, revision, revdate)

end subroutine typekind_error

end program preprocess

! <next few lines under version control, do not edit>
! $URL$
! $Id$
! $Revision$
! $Date$
