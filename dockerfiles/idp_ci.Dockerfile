FROM public.ecr.aws/docker/library/ruby:3.2.2-bullseye

ENV NODE_MAJOR 18

RUN mkdir -p /etc/apt/keyrings
RUN curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
RUN echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list

RUN wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - \
    && echo "deb http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list

RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
    && echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    nodejs \
    python3 \
    python3-pip \
    python3-venv \
    nodejs \
    locales \
    # google-chrome-stable \
    yarn

# This is temporary so that we do not use the latest chrome due to an issue in the latest version
ARG CHROME_VERSION="112.0.5615.165-1"
RUN wget --no-verbose -O /tmp/chrome.deb https://dl.google.com/linux/chrome/deb/pool/main/g/google-chrome-stable/google-chrome-stable_${CHROME_VERSION}_amd64.deb \
  && apt install -y /tmp/chrome.deb \
  && rm /tmp/chrome.deb
# This is temporary so that we do not use the latest chromedriver due to an issue in the latest version
# RUN curl -Ss "https://chromedriver.storage.googleapis.com/$(google-chrome --version | grep -Po '\d+\.\d+\.\d+' | tr -d '\n').16/chromedriver_linux64.zip" > /tmp/chromedriver.zip && \
RUN curl -Ss "https://chromedriver.storage.googleapis.com/$(curl -Ss "https://chromedriver.storage.googleapis.com/LATEST_RELEASE_$(google-chrome --version | grep -Po '\d+\.\d+\.\d+' | tr -d '\n')")/chromedriver_linux64.zip" > /tmp/chromedriver.zip && \
    unzip /tmp/chromedriver.zip -d /tmp/chromedriver && \
    mv -f /tmp/chromedriver/chromedriver /usr/local/bin/chromedriver && \
    rm /tmp/chromedriver.zip && \
    rm -r /tmp/chromedriver

# Install aws cli
ENV VIRTUAL_ENV=/opt/venv
RUN python3 -m venv $VIRTUAL_ENV
ENV PATH="$VIRTUAL_ENV/bin:$PATH"
RUN pip install awscli

RUN find / -perm /6000 -type f -exec chmod a-s {} \; || true
