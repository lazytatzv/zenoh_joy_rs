cmake_minimum_required(VERSION 3.8)
project(zenoh_joy_rs)

if(CMAKE_COMPILER_IS_GNUCXX OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
  add_compile_options(-Wall -Wextra -Wpedantic)
endif()

find_package(ament_cmake REQUIRED)

# Install Launch, Config, and Scripts into standard ROS 2 share directory
install(DIRECTORY
  config
  examples
  scripts
  DESTINATION share/${PROJECT_NAME}
)

install(DIRECTORY
  examples/launch
  DESTINATION share/${PROJECT_NAME}
)

# Install setup scripts with executable permissions
install(PROGRAMS
  scripts/setup_bt_pan.sh
  DESTINATION lib/${PROJECT_NAME}
)

ament_package()
