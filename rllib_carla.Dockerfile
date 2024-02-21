FROM nvidia/vulkan:1.2.133-450

ARG CARLA_VERSION=0.9.15
ARG DEBIAN_FRONTEND=noninteractive

USER root

RUN sed -i '/developer\.download\.nvidia\.com\/compute\/cuda\/repos/d' /etc/apt/sources.list \
    && sed -i '/developer\.download\.nvidia\.com\/compute\/cuda\/repos/d' /etc/apt/sources.list.d/* \
    && sed -i '/developer\.download\.nvidia\.com\/compute\/machine-learning\/repos/d' /etc/apt/sources.list.d/* \
    && apt-key del 7fa2af80 \
    && wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/cuda-keyring_1.0-1_all.deb \
    && dpkg -i cuda-keyring_1.0-1_all.deb \
    && rm -f cuda-keyring_1.0-1_all.deb

RUN apt-get update  \
    && apt-get install -y --no-install-recommends apt-utils  \
    && apt-get install -y wget

RUN apt-get install -y software-properties-common \
    && add-apt-repository ppa:deadsnakes/ppa \
    && apt-get install -y sudo htop tmux psmisc python3.7 python3-pip python-is-python3 git wget unzip g++ cmake tar  \
    && apt-get install -y libpng16-16 libjpeg-turbo8 libtiff5 libomp5 \
    && apt-get install -y libice6 libsm6 libxaw7 libxkbfile1 libxmu6 libxpm4 libxt6 x11-common x11-xkb-utils xkb-data

RUN packages='libsdl2-2.0 xserver-xorg libvulkan1 libomp5 xdg-user-dirs xdg-utils'  \
    && apt-get update  \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y $packages --no-install-recommends

### install turboVNC
RUN wget https://phoenixnap.dl.sourceforge.net/project/turbovnc/3.0.3/turbovnc_3.0.3_amd64.deb \
    && dpkg -i turbovnc*.deb \
    && rm -f turbovnc*.deb

### Install Carla 0.9.13
#RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 1AF1527DE64CB8D9 \
    #&& add-apt-repository "deb [arch=amd64] http://dist.carla.org/carla $(lsb_release -sc) main" \
    #&& apt-get update \
    #&& apt-get install carla-simulator -y

### Install Carla 0.9.15
RUN wget https://carla-releases.s3.us-east-005.backblazeb2.com/Linux/CARLA_${CARLA_VERSION}.tar.gz\
    && mkdir /home/CARLA_${CARLA_VERSION}\
    && tar -xvzf CARLA_${CARLA_VERSION}.tar.gz -C /home/CARLA_${CARLA_VERSION}\
    && rm -rf CARLA_${CARLA_VERSION}.tar.gz 
#RUN sudo chmod u+x /home/CARLA_${CARLA_VERSION}/CarlaUE4/Binaries/Linux/CarlaUE4-Linux-Shipping

### Install ROS2
RUN apt update && sudo apt install locales \
    && locale-gen en_US en_US.UTF-8 \
    && update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 \
    && export LANG=en_US.UTF-8
RUN apt install software-properties-common -y \
    && add-apt-repository universe \
    && apt update && sudo apt install curl -y \
    && curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main" | sudo tee /etc/apt/sources.list.d/ros2.list > /dev/null

SHELL ["/bin/bash", "-c"]

RUN sudo apt update -y && sudo apt upgrade -y \
    && sudo apt install -y ros-foxy-desktop python3-argcomplete \
    && sudo apt install -y ros-dev-tools \
    && source /opt/ros/foxy/setup.bash


### Install ros2_carla_bridge 
RUN mkdir -p /home/carla-ros-bridge && cd /home/carla-ros-bridge \
    && git clone --recurse-submodules https://github.com/carla-simulator/ros-bridge.git src/ros-bridge \
    &&  source /opt/ros/foxy/setup.bash \
    &&  sudo rosdep init \
    &&  rosdep update \
    &&  rosdep install --from-paths src --ignore-src -r \
    &&  colcon build

### used to enable machine-to-machine docker to docker communication
RUN sudo apt install ros-foxy-derived-object-msgs \
    && sudo apt install ros-foxy-rmw-cyclonedds-cpp -y \
    && sudo apt-get install ros-foxy-sensor-msgs-py

RUN sudo apt-get upgrade -y

### Install lego_carla
RUN useradd -ms /bin/bash lego_carla \
    && usermod -aG sudo lego_carla 

RUN sudo chmod u+x /home/CARLA_${CARLA_VERSION}/CarlaUE4/Binaries/Linux/CarlaUE4-Linux-Shipping

USER lego_carla
WORKDIR /home/lego_carla
ENV PATH="${PATH}:/home/lego_carla/.local/bin"

RUN pip3 install --user pygame numpy

RUN echo "export CARLA_ROOT=/home/CARLA_${CARLA_VERSION}" >> ~/.bashrc \
    && echo "export PYTHONPATH=\$PYTHONPATH:\${CARLA_ROOT}/PythonAPI/carla/dist/carla-${CARLA_VERSION}-py3.7-linux-x86_64.egg" >> ~/.bashrc \
    && echo "export PYTHONPATH=\$PYTHONPATH:\${CARLA_ROOT}/PythonAPI/carla/agents" >> ~/.bashrc \
    && echo "export PYTHONPATH=\$PYTHONPATH:\${CARLA_ROOT}/PythonAPI/carla" >> ~/.bashrc \
    && echo "export PYTHONPATH=\$PYTHONPATH:\${CARLA_ROOT}/PythonAPI" >> ~/.bashrc \
    && echo "source /opt/ros/foxy/setup.bash" >> ~/.bashrc \
    && echo "source /home/carla-ros-bridge/install/setup.bash" >> ~/.bashrc \
    && echo "export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp" >> ~/.bashrc  
    #RMW_IMPEMENTATION enable docker to docker communication

#COPY --chown=lego_carla:lego_carla /carla-ros-bridge/src /home/lego_carla/src 
RUN pip3 install torch torchvision torchaudio \
    && pip install -U openmim \
    && pip install mmengine \
    && pip install mmcv==2.1.0 -f https://download.openmmlab.com/mmcv/dist/cu121/torch2.1/index.html\
    && pip install mmdet\
    && pip install "mmdet3d>=1.1.0"
#RUN pip install rosnumpy


ARG CACHEBUST=2
RUN mkdir -p /home/lego_carla/src && cd /home/lego_carla/src \
    && git clone https://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@github.com/UCR-CISL/LegoCarla.git \   
    && cd .. \
    && source /opt/ros/foxy/setup.bash \
    && rosdep update \
    && rosdep install --from-paths src --ignore-src -r \
    && colcon build \
    && source ./install/setup.bash \
    && echo "source /home/lego_carla/install/setup.bash" >> ~/.bashrc 

ARG CACHEBUST=6
RUN mkdir -p /home/lego_carla/src && cd /home/lego_carla/src \
    && git clone https://github.com/JiapengZhao1/rllib-integration-test.git
    #&& cd ./rllib-integration

RUN cd /home/lego_carla/src/rllib-integration-test \
    && pip3 install -r requirements.txt 

RUN cd /home/lego_carla/src/rllib-integration-test \ 
    && pip3 install -r ./dqn_example/dqn_requirements.txt