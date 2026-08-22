cmake_minimum_required(VERSION 3.8)
project(zenoh_joy_rs)

if(CMAKE_COMPILER_IS_GNUCXX OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
  add_compile_options(-Wall -Wextra -Wpedantic)
endif()

find_package(ament_cmake REQUIRED)

# Install Launch, Config, and Examples into standard ROS 2 share directory
install(DIRECTORY
  config
  examples
  DESTINATION share/${PROJECT_NAME}
)

install(DIRECTORY
  examples/launch
  DESTINATION share/${PROJECT_NAME}
)

ament_package()
