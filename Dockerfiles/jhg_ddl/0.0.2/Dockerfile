FROM ubuntu:16.04

# newer versions of gatk have picard wrapped in, but I don't want to dig up what version of picard this is using
ENV PICARD_URL https://github.com/broadinstitute/picard/releases/download/2.26.10/picard.jar
ENV DATAMASH_URL https://ftp.gnu.org/gnu/datamash/datamash-1.6.tar.gz
ENV DATAMASH_MD5 = "c3c243278a2f35de5ce988c844f8e240"
# installing newer versions and overwriting previously installed versions
ENV SAMTOOLS_URL https://github.com/samtools/samtools/releases/download/1.10/samtools-1.10.tar.bz2
ENV PIGZ_URL https://zlib.net/pigz/pigz-2.7.tar.gz

SHELL ["/bin/bash", "-c"]

RUN mkdir -p /downloads
RUN mkdir -p /picard
WORKDIR /downloads

RUN apt-get update -qq && \
	apt-get install -qq \
	bzip2 \
	tzdata \
	gcc \
	g++ \
	make \
	zlib1g-dev \
	wget \
	perl \
	libncurses5-dev \
	libbz2-dev \
	liblzma-dev \
	openjdk-8-jdk

RUN wget -nv $PICARD_URL && \
	mv picard.jar /picard/picard.jar && \
	rm -rf /downloads/picard.jar

RUN wget -nv $DATAMASH_URL && \
	tar -xzf datamash-1.6.tar.gz && \
	cd datamash-1.6 && \
	./configure && \
	make && \
	make check && \
	make install && \
	cd .. && \
	rm -rf datamash-1.6*

RUN wget -nv $SAMTOOLS_URL && \
	tar -xvf samtools-1.10.tar.bz2 && \
	cd samtools-1.10 && \
	./configure --prefix=/usr && \
	make all all-htslib && \
	make install install-htslib && \
	cd .. && \
	rm -rf samtools-1.10*

RUN wget -nv $PIGZ_URL && \
	tar -xvf pigz-2.7.tar.gz && \
	cd pigz-2.7 && \
	make && \
	mv {pigz,unpigz} /usr/local/bin && \
	cd .. && \
	rm -rf pigz-2.7*
