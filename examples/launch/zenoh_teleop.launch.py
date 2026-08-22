"""
Example ROS 2 Launch File for Robot Integration
Starts standard zenoh-bridge-ros2dds with teleoperation configuration.
"""

from pathlib import Path
from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node

def generate_launch_description():
    pkg_dir = Path(__file__).resolve().parent.parent
    default_config = str(pkg_dir / "ros2_zenoh_bridge.json5")

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
