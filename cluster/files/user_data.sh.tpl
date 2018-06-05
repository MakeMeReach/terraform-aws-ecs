#!/bin/bash

echo 'ECS_CLUSTER=${cluster_name}' >> /etc/ecs/ecs.config
sudo restart ecs

${custom_userdata}
