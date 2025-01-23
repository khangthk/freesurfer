# Qt Find Module

if(NOT Qt6_DIR)
   if(NOT Qt5_DIR)
     # default search path
     if(EXISTS ${FS_PACKAGES_DIR}/qt/5.11/lib/cmake/Qt5)
       set(Qt5_DIR ${FS_PACKAGES_DIR}/qt/5.11/lib/cmake/Qt5)
     elseif(EXISTS ${FS_PACKAGES_DIR}/qt/5.6/lib/cmake/Qt5)
       set(Qt5_DIR ${FS_PACKAGES_DIR}/qt/5.6/lib/cmake/Qt5)
     endif()
   endif()
endif()

# find Qt components
set(_qt_components Core Widgets)
if(NOT APPLE)
  set(_qt_components ${_qt_components} X11Extras)
endif()

if(Qt6_DIR)
   find_package(Qt6 COMPONENTS ${_qt_components})
elseif(Qt5_DIR)
   find_package(Qt5 COMPONENTS ${_qt_components})
endif()

# cmake doesn't easily provide us with a cross-platform path to
# root qt install directory, so we'll use the hidden QtCore prefix
if(Qt6_DIR)
   set(Qt6_INSTALL_DIR ${_qt6Core_install_prefix})
   if(APPLE)
     # find_package function fails to set _qt_components with Qt6 (but not Qt5), so set Qt6 paths based upon Qt6_DIR.
     # The bug for Qt6 being unable to find modules was supposed to have been fixed in 6.4, but still did not work for me.
     # So the cmake command line needs to set both Qt6_DIR and Qt6GuiTools_DIR. A relative path for Qt6_INSTALL_DIR does work.
     set(Qt6_INSTALL_DIR ${Qt6_DIR}/../../..)
     # set(Qt6GuiTools_DIR ${Qt6_DIR}GuiTools)
     set(MAC_QT_INSTALL_DIR ${Qt6_INSTALL_DIR})
   endif()
elseif(Qt5_DIR)
   set(Qt5_INSTALL_DIR ${_qt5Core_install_prefix})
   if(APPLE)
     set(MAC_QT_INSTALL_DIR ${Qt5_INSTALL_DIR})
   endif()
endif()

function(install_qt5_lib_links)
   install(CODE "
     message(STATUS \"Install links to native qt5 libs\")
     file(MAKE_DIRECTORY ${CMAKE_INSTALL_PREFIX}/lib/qt/lib)
     message(STATUS \"(cd ${Qt5_BASE}/lib && tar cpf - lib*) | (cd ${CMAKE_INSTALL_PREFIX}/lib/qt/lib && tar xvpf - )\")
     execute_process(COMMAND bash -c \"(cd ${Qt5_BASE}/lib && tar cpf - lib*) | (cd ${CMAKE_INSTALL_PREFIX}/lib/qt/lib && tar xvpf - )\" RESULT_VARIABLE retcode)
     if(NOT \${retcode} STREQUAL 0)
       message(FATAL_ERROR \"Could not install qt5 lib links\")
     endif()"
     COMPONENT qtlib
   )
endfunction()

function(install_qt5_plugins_platform_links)
   install(CODE "
     message(STATUS \"Install links to native qt5 platform plugins\")
     file(MAKE_DIRECTORY ${CMAKE_INSTALL_PREFIX}/lib/qt/plugins)
     message(STATUS \"(cd ${Qt5_BASE}/plugins && tar cpf - platforms) | (cd ${CMAKE_INSTALL_PREFIX}/lib/qt/plugins && tar xvpf - )\")
     execute_process(COMMAND bash -c \"(cd ${Qt5_BASE}/plugins && tar cpf - platforms) | (cd ${CMAKE_INSTALL_PREFIX}/lib/qt/plugins && tar xvpf - )\" RESULT_VARIABLE retcode)
     if(NOT \${retcode} STREQUAL 0)
       message(FATAL_ERROR \"Could not install qt5 platform plugins\")
     endif()"
     COMPONENT qtplatform
   )
endfunction()

function(install_qt5_plugins_imageformat_links)
   install(CODE "
     message(STATUS \"Install links to native qt5 imageformat plugins\")
     file(MAKE_DIRECTORY ${CMAKE_INSTALL_PREFIX}/lib/qt/plugins)
     message(STATUS \"(cd ${Qt5_BASE}/plugins && tar cpf - imageformats) | (cd ${CMAKE_INSTALL_PREFIX}/lib/qt/plugins && tar xvpf - )\")
     execute_process(COMMAND bash -c \"(cd ${Qt5_BASE}/plugins && tar cpf - imageformats) | (cd ${CMAKE_INSTALL_PREFIX}/lib/qt/plugins && tar xvpf - )\" RESULT_VARIABLE retcode)
     if(NOT \${retcode} STREQUAL 0)
       message(FATAL_ERROR \"Could not install qt5 imageformat plugins\")
     endif()"
     COMPONENT qtimage
   )
endfunction()

# install the shared libraries to the freesurfer lib directory
if(Qt5_FOUND AND NOT APPLE)
  if (NOT QT_SYSLIBS)
     file(GLOB _qt_libs_to_install "${Qt5_INSTALL_DIR}/lib/lib*.so*")
     if(_qt_libs_to_install)
       install(PROGRAMS ${_qt_libs_to_install} DESTINATION lib/qt/lib)
       # add Qt library directory to rpath
       set(CMAKE_INSTALL_RPATH "$ORIGIN/../lib/qt/lib:${CMAKE_INSTALL_RPATH}")
       # install the platform plugins
       if(EXISTS ${Qt5_INSTALL_DIR}/plugins/platforms)
         install(DIRECTORY ${Qt5_INSTALL_DIR}/plugins/platforms DESTINATION lib/qt/plugins)
       endif()
       # install the image format plugins
       if(EXISTS ${Qt5_INSTALL_DIR}/plugins/imageformats)
         install(DIRECTORY ${Qt5_INSTALL_DIR}/plugins/imageformats DESTINATION lib/qt/plugins)
       endif()
       # make sure executables know where to find the plugins directory
       install(FILES ${CMAKE_SOURCE_DIR}/qt/qt.conf DESTINATION bin)
     endif()
  else()
     # The /usr/pubsw/packages qt distro contains soft links pointing to the system Qt5 files,
     # so install via functions and do not use EXISTS/GLOB tests.
     install_qt5_lib_links()
     # add Qt library directory to rpath
     set(CMAKE_INSTALL_RPATH "$ORIGIN/../lib/qt/lib:${CMAKE_INSTALL_RPATH}")
     # install the platform plugins
     install_qt5_plugins_platform_links()
     # install the image format plugins
     install_qt5_plugins_imageformat_links()
     # make sure executables know where to find the plugins directory
     install(FILES ${CMAKE_SOURCE_DIR}/qt/qt.conf DESTINATION bin)
  endif()
endif()
