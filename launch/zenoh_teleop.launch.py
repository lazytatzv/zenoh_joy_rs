"""
Production ROS 2 Launch File for Zenoh Teleop Bridge
Works out of the box with standard 'ros2 launch zenoh_joy_rs zenoh_teleop.launch.py'
"""

from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument
from launch.substitutions import LaunchConfiguration, PathJoinSubstitution
from launch_ros.actions import Node
from launch_ros.substitutions import FindPackageShare

def generate_launch_description():
    pkg_share = FindPackageShare("zenoh_joy_rs")
    default_config = PathJoinSubstitution([pkg_share, "examples", "ros2_zenoh_bridge.json5"])

    config_arg = DeclareLaunchArgument(
        "zenoh_config",
        default_value=default_config,
        description="Path to the zenoh-bridge-ros2dds json5 configuration file"
    )

    zenoh_bridge_node = Node(
        package="zenoh_bridge_ros2dds",
        executable="zenoh_bridge_ros2dds",
        name="zenoh_bridge_teleop",
        arguments=["-c", LaunchConfiguration("zenoh_config")],
        output="screen",
        respawn=True,
        respawn_delay=2.0
    )

    return LaunchDescription([
        config_arg,
        zenoh_bridge_node
    ])
