#!/bin/bash

sudo ovs-vsctl del-br AccessNet
sudo ovs-vsctl del-br ExtNet
sudo ovs-vsctl add-br AccessNet
sudo ovs-vsctl add-br ExtNet
