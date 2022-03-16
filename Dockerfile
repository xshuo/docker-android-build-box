FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive \
    TERM=dumb

# context print
RUN echo "current shell is $SHELL"
RUN ls -al /bin/sh
RUN ls -al /bin/bash
RUN rm /bin/sh && ln -sf /bin/bash /bin/sh
RUN uname -a && uname -m

# change to aliyun
RUN sed -i s@/archive.ubuntu.com/@/mirrors.aliyun.com/@g /etc/apt/sources.list

RUN apt-get clean && apt-get update && apt install -y apt-utils

# set timezone
ENV TZ=Asia/Shanghai
RUN apt install -y tzdata \
    && ln -fs /usr/share/zoneinfo/${TZ} /etc/localtime \
    && echo ${TZ} > /etc/timezone \
    && dpkg-reconfigure --frontend noninteractive tzdata

# Set locale
ENV LANG="en_US.UTF-8" \
    LANGUAGE="en_US.UTF-8" \
    LC_ALL="en_US.UTF-8"
RUN apt-get install -y locales && locale-gen $LANG


ENV ANDROID_HOME="/opt/android-sdk" \
    ANDROID_NDK="/opt/android-sdk/ndk" \
    FLUTTER_HOME="/opt/flutter"

# java env
# support amd64 and arm64
RUN JDK_PLATFORM=$(if [ "$(uname -m)" = "aarch64" ]; then echo "arm64"; else echo "amd64"; fi) && \
    echo export JDK_PLATFORM=$JDK_PLATFORM >> /etc/jdk.env && \
    echo export JAVA_HOME="/usr/lib/jvm/java-11-openjdk-$JDK_PLATFORM/" >> /etc/jdk.env && \
    echo . /etc/jdk.env >> /etc/bash.bashrc && \
    echo . /etc/jdk.env >> /etc/profile

# nodejs version
ENV NODE_VERSION="14.x"

WORKDIR /tmp

# Installing packages
RUN apt-get update -qq > /dev/null && \
    apt-get install -y --no-install-recommends \
        autoconf \
        build-essential \
        curl \
        file \
        git \
        gpg-agent \
        less \
        libc6-dev \
        libgmp-dev \
        libmpc-dev \
        libmpfr-dev \
        libxslt-dev \
        libxml2-dev \
        m4 \
        ncurses-dev \
        ocaml \
        openjdk-8-jdk \
        openjdk-11-jdk \
        openssh-client \
        pkg-config \
        ruby-full \
        software-properties-common \
        tzdata \
        unzip \
        vim-tiny \
        wget \
        zip \
        zlib1g-dev && \
    echo "JVM directories: `ls -l /usr/lib/jvm/`" && \
    echo "Java version (default):" && \
    java -version && \
    echo "nodejs, npm, cordova, ionic, react-native" && \
    curl -sL -k https://deb.nodesource.com/setup_${NODE_VERSION} \
        | bash - > /dev/null && \
    apt-get install -qq nodejs > /dev/null && \
    apt-get clean > /dev/null && \
    curl -sS -k https://dl.yarnpkg.com/debian/pubkey.gpg \
        | apt-key add - > /dev/null && \
    echo "deb https://dl.yarnpkg.com/debian/ stable main" \
        | tee /etc/apt/sources.list.d/yarn.list > /dev/null && \
    apt-get update -qq > /dev/null && \
    apt-get install -qq yarn > /dev/null && \
    rm -rf /var/lib/apt/lists/ && \
    npm install --quiet -g npm > /dev/null && \
    npm install --quiet -g \
        bower \
        cordova \
        eslint \
        gulp \
        ionic \
        jshint \
        karma-cli \
        mocha \
        node-gyp \
        npm-check-updates \
        react-native-cli > /dev/null && \
    npm cache clean --force > /dev/null && \
    rm -rf /tmp/* /var/tmp/*


ENV PATH="$JAVA_HOME/bin:$ANDROID_SDK/cmdline-tools/bin:$ANDROID_SDK/emulator:$ANDROID_SDK/tools/bin:$ANDROID_SDK/tools:$ANDROID_SDK/platform-tools:$ANDROID_NDK:$FLUTTER_HOME/bin:$FLUTTER_HOME/bin/cache/dart-sdk/bin:$PATH"

#cmdline tools
# Get the latest version from https://developer.android.com/studio/index.html
ENV ANDROID_COMMANDLINE_TOOLS_VERSION_CODE=8092744
ENV ANDROID_COMMANDLINE_TOOLS_VERSION=latest
ENV ANDROID_COMMANDLINE_TOOLS_URL="https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_COMMANDLINE_TOOLS_VERSION_CODE}_${ANDROID_COMMANDLINE_TOOLS_VERSION}.zip"

# Install Android SDK
# commandline tools
# https://dl.google.com/android/repository/commandlinetools-linux-8092744_latest.zip
RUN echo "command line tools ${ANDROID_COMMANDLINE_TOOLS_URL}" && \
    wget --quiet --output-document=cmdline-tools.zip ${ANDROID_COMMANDLINE_TOOLS_URL} && \
    mkdir --parents $ANDROID_HOME && \
    unzip -q cmdline-tools.zip -d $ANDROID_HOME && \
    rm --force cmdline-tools.zip

RUN ls -l $ANDROID_HOME

ENV ANDROID_SDK_MANAGER_BIN="$ANDROID_HOME/cmdline-tools/bin/sdkmanager --sdk_root=$ANDROID_HOME"
# Install SDKs
# Please keep these in descending order!
# The `yes` is for accepting all non-standard tool licenses.
RUN mkdir --parents "$ANDROID_HOME/.android/" && \
    echo '### User Sources for Android SDK Manager' > "$ANDROID_HOME/.android/repositories.cfg" && \
    yes | $ANDROID_SDK_MANAGER_BIN --licenses > /dev/null

# List all available packages.
# redirect to a temp file `packages.txt` for later use and avoid show progress
RUN $ANDROID_SDK_MANAGER_BIN --list

#
# https://developer.android.com/studio/command-line/sdkmanager.html
#
RUN echo "platforms" && \
    yes | $ANDROID_SDK_MANAGER_BIN \
        "platforms;android-30" \
        "platforms;android-31" \
        "platforms;android-32" \
	 > /dev/null

RUN echo "platform tools" && \
    yes | $ANDROID_SDK_MANAGER_BIN "platform-tools" > /dev/null

RUN echo ls -l $ANDROID_HOME

RUN echo "build tools" && yes | $ANDROID_SDK_MANAGER_BIN \
        "build-tools;30.0.3" \
        "build-tools;31.0.0" \
        "build-tools;32.0.0" \
        > /dev/null

# seems there is no emulator on arm64
# Warning: Failed to find package emulator
RUN echo "emulator" && \
    if [ "$(uname -m)" != "x86_64" ]; then echo "emulator only support Linux x86 64bit. skip for $(uname -m)"; exit 0; fi && \
    yes | $ANDROID_SDK_MANAGER_BIN "emulator" > /dev/null

# ndk-bundle does exist on arm64

RUN echo "NDK" && \
    yes | $ANDROID_SDK_MANAGER_BIN "ndk;19.2.5345600" > /dev/null

RUN echo "cmake" && \
    yes | $ANDROID_SDK_MANAGER_BIN "cmake;3.18.1" "cmake;3.10.2.4988404"

# List sdk and ndk directory content
RUN ls -l $ANDROID_HOME && \
    ls -l $ANDROID_HOME/ndk

RUN du -sh $ANDROID_HOME

RUN echo "Flutter sdk" && \
    if [ "$(uname -m)" != "x86_64" ]; then echo "Flutter only support Linux x86 64bit. skip for $(uname -m)"; exit 0; fi && \
    cd /opt && \
    wget --quiet https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_2.8.1-stable.tar.xz -O flutter.tar.xz && \
    tar xf flutter.tar.xz && \
    flutter config --no-analytics && \
    rm -f flutter.tar.xz

# Copy sdk license agreement files.
RUN mkdir -p $ANDROID_HOME/licenses
COPY sdk/licenses/* $ANDROID_HOME/licenses/

# Create some jenkins required directory to allow this image run with Jenkins
RUN mkdir -p /var/lib/jenkins/workspace && \
    mkdir -p /home/jenkins && \
    chmod 777 /home/jenkins && \
    chmod 777 /var/lib/jenkins/workspace && \
    chmod -R 775 $ANDROID_HOME

COPY Gemfile /Gemfile

RUN echo "fastlane" && \
    cd / && \
    gem install bundler --quiet --no-document > /dev/null && \
    mkdir -p /.fastlane && \
    chmod 777 /.fastlane && \
    bundle install --quiet

# Add jenv to control which version of java to use, default to 11.
RUN git clone https://github.com/jenv/jenv.git ~/.jenv && \
    echo 'export PATH="$HOME/.jenv/bin:$PATH"' >> ~/.bash_profile && \
    echo 'eval "$(jenv init -)"' >> ~/.bash_profile && \
    . ~/.bash_profile && \
    . /etc/jdk.env && \
    java -version && \
    jenv add /usr/lib/jvm/java-8-openjdk-$JDK_PLATFORM && \
    jenv add /usr/lib/jvm/java-11-openjdk-$JDK_PLATFORM && \
    jenv versions && \
    jenv global 11 && \
    java -version

COPY README.md /README.md

ARG BUILD_DATE=""
ARG SOURCE_BRANCH=""
ARG SOURCE_COMMIT=""
ARG DOCKER_TAG=""

ENV BUILD_DATE=${BUILD_DATE} \
    SOURCE_BRANCH=${SOURCE_BRANCH} \
    SOURCE_COMMIT=${SOURCE_COMMIT} \
    DOCKER_TAG=${DOCKER_TAG}

WORKDIR /project

# labels, see http://label-schema.org/
LABEL maintainer="Ming Chen"
LABEL org.label-schema.schema-version="1.0"
LABEL org.label-schema.name="mingc/android-build-box"
LABEL org.label-schema.version="${DOCKER_TAG}"
LABEL org.label-schema.usage="/README.md"
LABEL org.label-schema.docker.cmd="docker run --rm -v `pwd`:/project mingc/android-build-box bash -c 'cd /project; ./gradlew build'"
LABEL org.label-schema.build-date="${BUILD_DATE}"
LABEL org.label-schema.vcs-ref="${SOURCE_COMMIT}@${SOURCE_BRANCH}"
