#!/bin/bash
set -eu

base_dir=$(cd "`dirname "$0"`" && pwd)

if [ ! -d $base_dir/opencv ]; then
    git clone -b 4.6.0 --depth 1 https://github.com/opencv/opencv.git $base_dir/opencv
fi

if [ ! -d $base_dir/opencv_contrib ]; then
    git clone -b 4.6.0 --depth 1 https://github.com/opencv/opencv_contrib.git $base_dir/opencv_contrib
fi

# register wechat_qrcode function return type std::vector<std::string>
sed -i '/register_vector<double>/a\
    register_vector<std::string>("StringVector");' $base_dir/opencv/modules/js/src/core_bindings.cpp

# workaround for opencv buggy embindgen.py
sed -i 's/std::string/String/g' $base_dir/opencv_contrib/modules/wechat_qrcode/include/opencv2/wechat_qrcode.hpp
sed -i 's/type_dict\[key\], ret_type/r"\\1"+type_dict[key]+r"\\2", ret_type/g' $base_dir/opencv/modules/js/generator/embindgen.py

# workaround for cv::utils::fs::exists not implemented, comment out CV_Assert
sed -i 's/[ \t]*CV_Assert/\/\/&/' $base_dir/opencv_contrib/modules/wechat_qrcode/src/wechat_qrcode.cpp

# modify export variables config of wasm
sed -i "/white_list/i \
wechat_qrcode = {'wechat_qrcode_WeChatQRCode':['WeChatQRCode','detectAndDecode', 'setScaleFactor','getScaleFactor']}" \
$base_dir/opencv/platforms/js/opencv_js.config.py
sed -i "s/white_list.*/white_list = makeWhiteList([core,imgproc,video,photo,wechat_qrcode])/" \
$base_dir/opencv/platforms/js/opencv_js.config.py

# bundle wechat_qrcode model files
echo "target_link_options(\${the_module} INTERFACE --preload-file \${CMAKE_BINARY_DIR}/downloads/wechat_qrcode@wechat_qrcode)" \
>> $base_dir/opencv_contrib/modules/wechat_qrcode/CMakeLists.txt

python3 $base_dir/opencv/platforms/js/build_js.py build_wasm --build_wasm --emscripten_dir=$EMSDK/upstream/emscripten \
--cmake_option="-DOPENCV_EXTRA_MODULES_PATH=$base_dir/opencv_contrib/modules/wechat_qrcode"
