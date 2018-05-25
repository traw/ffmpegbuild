
function make_dir () {
	if [ ! -d $1 ]; then
		if ! mkdir $1; then			
			printf "\n Failed to create dir %s" "$1";
			exit 1
		fi
	fi	
}

function remove_dir () {
	if [ -d $1 ]; then
		rm -r "$1"
	fi	
}

function download () {
	if [ ! -f "$PACKAGES/$2" ]; then
		
		echo "Downloading $1"
		curl -L --silent -o "$PACKAGES/$2" "$1"
		
		EXITCODE=$?
		if [ $EXITCODE -ne 0 ]; then
			echo ""
			echo "Failed to download $1. Exitcode $EXITCODE. Retrying in 10 seconds";
			sleep 10
			curl -L --silent -o "$PACKAGES/$2" "$1"
		fi
		
		EXITCODE=$?
		if [ $EXITCODE -ne 0 ]; then
			echo ""
			echo "Failed to download $1. Exitcode $EXITCODE";
			exit 1
		fi
		
		echo "... Done"
		
		if ! tar -xvf "$PACKAGES/$2" -C "$PACKAGES" 2>/dev/null >/dev/null; then
			echo "Failed to extract $2";
			exit 1
		fi
		
	fi
}

function execute () {
	echo "$ $*"
	
	if [[ ! $VERBOSE == "yes" ]]; then
		OUTPUT="$($@ 2>&1)"
	else
		$@
	fi
	
	if [ $? -ne 0 ]; then
        echo "$OUTPUT"
        echo ""
        echo "Failed to Execute $*" >&2
        exit 1
    fi
}


function check::build () {
	echo ""
	echo "building $1"
	echo "======================="
	
	if [ -f "$PACKAGES/$1.done" ]; then
		echo "$1 already built. Remove $PACKAGES/$1.done lockfile to rebuild it."
		return 1
	fi
	
	return 0
}

function command_exists() {
    if ! [[ -x $(command -v "$1") ]]; then
        return 1
    fi

    return 0
}


function build_done () {
	touch "$PACKAGES/$1.done"
}

function numjobs () {
	# Speed up the process
	# Env Var NUMJOBS overrides automatic detection
	local mjobs
	if [[ -f /proc/cpuinfo ]]; then
		mjobs=$(grep -c processor /proc/cpuinfo)
	elif [[ "$OSTYPE" == "darwin"* ]]; then
		mjobs=$(sysctl -n machdep.cpu.thread_count)
	else
		mjobs=4
	fi
	echo "$mjobs"
}

function build::yasm () {
	download "http://www.tortall.net/projects/yasm/releases/yasm-1.3.0.tar.gz" "yasm-1.3.0.tar.gz"
	cd $PACKAGES/yasm-1.3.0 || exit
	execute ./configure --prefix=${WORKSPACE}
	execute make -j $MJOBS 
	execute make install
	build_done "yasm"
}

function build::libvpx () {
    download "https://github.com/webmproject/libvpx/archive/v1.7.0.tar.gz" "libvpx-1.7.0.tar.gz"
    cd $PACKAGES/libvpx-*0 || exit
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "Applying Darwin patch"
        sed "s/,--version-script//g" build/make/Makefile > build/make/Makefile.patched
        sed "s/-Wl,--no-undefined -Wl,-soname/-Wl,-undefined,error -Wl,-install_name/g" build/make/Makefile.patched > build/make/Makefile
    fi
    
	execute ./configure --prefix=${WORKSPACE} --disable-unit-tests --disable-shared
	execute make -j $MJOBS
	execute make install
	build_done "libvpx"
}

function build::lame () {
	download "http://kent.dl.sourceforge.net/project/lame/lame/3.100/lame-3.100.tar.gz" "lame-3.100.tar.gz"
	cd $PACKAGES/lame-3.100 || exit
	execute ./configure --prefix=${WORKSPACE} --disable-shared --enable-static
	execute make -j $MJOBS
	execute make install
	build_done "lame"
}

function build::nasm () {
	download "http://www.nasm.us/pub/nasm/releasebuilds/2.13.03/nasm-2.13.03.tar.gz" "nasm.tar.gz"
	cd $PACKAGES/nasm-2.13.03 || exit
	execute ./configure --prefix=${WORKSPACE} --disable-shared --enable-static
	execute make -j $MJOBS
	execute make install
	build_done "nasm"
}

function build::x264 () {
	download "ftp://ftp.videolan.org/pub/x264/snapshots/x264-snapshot-20170328-2245.tar.bz2" "last_x264.tar.bz2"
	cd $PACKAGES/x264-snapshot-* || exit
	execute ./configure --prefix=${WORKSPACE} --enable-static
	execute make -j $MJOBS
	execute make install
	execute make install-lib-static
	build_done "x264"
}

function build::x265 () {
	download "https://bitbucket.org/multicoreware/x265/downloads/x265_2.6.tar.gz" "x265-2.6.tar.gz"
	cd $PACKAGES/x265_* || exit
	cd source || exit
	execute cmake -DCMAKE_INSTALL_PREFIX:PATH=${WORKSPACE} -DENABLE_SHARED:bool=off . 
	execute make -j $MJOBS
	execute make install
	sed "s/-lx265/-lx265 -lstdc++/g" "$WORKSPACE/lib/pkgconfig/x265.pc" > "$WORKSPACE/lib/pkgconfig/x265.pc.tmp"
	mv "$WORKSPACE/lib/pkgconfig/x265.pc.tmp" "$WORKSPACE/lib/pkgconfig/x265.pc"
	build_done "x265"
}

function build::fdk_aac () {
	download "http://downloads.sourceforge.net/project/opencore-amr/fdk-aac/fdk-aac-0.1.5.tar.gz?r=https%3A%2F%2Fsourceforge.net%2Fprojects%2Fopencore-amr%2Ffiles%2Ffdk-aac%2F&ts=1457561564&use_mirror=kent" "fdk-aac-0.1.5.tar.gz"
	cd $PACKAGES/fdk-aac* || exit
	execute ./configure --prefix=${WORKSPACE} --disable-shared --enable-static
	execute make -j $MJOBS
	execute make install
	build_done "fdk_aac"
}

function build::ffmpeg () {
	download "http://ffmpeg.org/releases/ffmpeg-3.4.1.tar.bz2" "ffmpeg-snapshot.tar.bz2"
	cd $PACKAGES/ffmpeg* || exit
	CFLAGS="-I$WORKSPACE/include" LDFLAGS="-L$WORKSPACE/lib" 
	export PKG_CONFIG_PATH=$PKG_CONFIG_DIR 
	execute ./configure --arch=64 --prefix=${WORKSPACE} --extra-cflags="-I$WORKSPACE/include" --extra-ldflags="-L$WORKSPACE/lib" --extra-version=static --extra-cflags=--static --enable-static --disable-debug --disable-shared --disable-ffserver --disable-doc --enable-gpl --enable-version3 --enable-nonfree --enable-libvpx --enable-libmp3lame --enable-libx264 --enable-libx265 --enable-libfdk-aac --enable-runtime-cpudetect --enable-pthreads --enable-avfilter --enable-filters 
	execute make -j $MJOBS
	execute make install
}

function build () {
	build::yasm 
	build::libvpx 
	build::lame 
	build::nasm 
	build::x264 
	build::fdk_aac 
	build::x265 
	build::ffmpeg 
	echo ""
	echo "Building done. The binary can be found here: $WORKSPACE/bin/ffmpeg"
	echo ""
}

function clean () {
	remove_dir $PACKAGES
	remove_dir $WORKSPACE
	echo "Cleanup done."
	echo ""
	exit 0
}
