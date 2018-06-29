FROM fauria/vsftpd

RUN yum -y install automake \
    fuse \
    fuse-devel \
    gcc-c++ \
    git \
    libcurl-devel \
    libxml2-devel \
    make \
    openssl-devel

RUN git clone --branch v1.82 https://github.com/s3fs-fuse/s3fs-fuse.git && \
    cd s3fs-fuse && \
    ./autogen.sh && \
    ./configure && \
    make && \
    make install

RUN mkdir -p /s3fs/cred

RUN mkdir /s3fs/vsftpd
RUN chown ftp:ftp /s3fs/vsftpd

COPY vsftpd.conf /etc/vsftpd/
COPY run-vsftpd.sh /usr/sbin/
RUN chmod +x /usr/sbin/run-vsftpd.sh

RUN mkdir /ssl
COPY server.* /ssl/
