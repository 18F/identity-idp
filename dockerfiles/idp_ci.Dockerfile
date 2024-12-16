FROM public.ecr.aws/docker/library/ruby:3.3.4-bullseye

ENV NODE_MAJOR 20

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
    google-chrome-stable \
    graphviz \
    yarn

RUN curl -Ss "https://storage.googleapis.com/chrome-for-testing-public/$(google-chrome --version | grep -Po '\d+\.\d+\.\d+\.\d+' | tr -d '\n')/linux64/chromedriver-linux64.zip" > /tmp/chromedriver.zip && \
    unzip /tmp/chromedriver.zip -d /tmp/chromedriver && \
    mv -f /tmp/chromedriver/chromedriver-linux64/chromedriver /usr/local/bin/chromedriver && \
    rm /tmp/chromedriver.zip && \
    rm -r /tmp/chromedriver

# Install aws cli
ENV VIRTUAL_ENV=/opt/venv
RUN python3 -m venv $VIRTUAL_ENV
ENV PATH="$VIRTUAL_ENV/bin:$PATH"
RUN pip install awscli

RUN find / -perm /6000 -type f -exec chmod a-s {} \; || true
