cmake_minimum_required(VERSION 3.8)
project(zenoh_joy_rs)

if(CMAKE_COMPILER_IS_GNUCXX OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
  add_compile_options(-Wall -Wextra -Wpedantic)
endif()

find_package(ament_cmake REQUIRED)

# Install standard ROS 2 directories
install(DIRECTORY
  launch
  config
  examples
  DESTINATION share/${PROJECT_NAME}
)

ament_package()
