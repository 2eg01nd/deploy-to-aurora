#!/bin/bash

options="p:t:s:d:m:h"
parsed_options=$(getopt -o $options -- "$@")

if [ $? -ne 0 ]; then
	echo -e "\n---\tError command!\n"
	exit 1
fi

eval set -- "$parsed_options"

build_path="."
sign_profile=""
install_device=""
package_manager="apm"

while true; do
	case "$1" in
		-p)
			build_path=$2
			shift 2
			;;
		-t)
			target=$2
			shift 2
			;;
		-s)
			sign_profile=$2
			shift 2
			;;
		-d)
			install_device=$2
			shift 2
			;;
		-m)
			package_manager=$2
			shift 2
			;;
		?|-h)
			echo -e '\nUsage: $0 [-t] TARGET_NAME [-s] SIGN_TYPE [-d] DEVICE [-b] BUILD PATH [-p] PACKAGE MANAGER\n
			-t Target name from sdk-assistant list.\n
			-s Type sign key.pem and cert.pem.\n
			-p Root path where build project.\n
			-m Choose package manager(APM, pkcon, rpm).\n
			-d device name ip and username or name from .ssh/config.\n' >&2
			exit 0
			;;
		--)
			shift
			break
			;;
		*)	echo -e "\n---\tInvalid option: $1\n"
			exit 1
			;;
	esac
done

echo -e "PATH: $build_path"
rpm_file_count=$(ls -l $build_path/rpm/*.spec 2>/dev/null | wc -l)
if [ $rpm_file_count -eq 0 ]; then
	echo -e "\n---\tNot found .spec files.\n"
	exit 1;
elif [ $rpm_file_count -gt 1 ]; then
	echo -e "\n---\tFound more than one .spec file\n"
	exit 1;
else
	spec_file=$(basename $build_path/rpm/*.spec)
	echo -e "\n+++\tFound $spec_file file.\n"
fi

echo -e "\n***\tBuild packages.\n"
mb2 --target $target build -p --no-check $build_path

if [ -z "$sign_profile" ]; then
	echo -e "\n***\tOnly build packages.\n"
	exit 0
fi

key_sign_file_count=$(ls -l $HOME/Keys/developer-$sign_profile-release/key.pem  2>/dev/null | wc -l)

if [ $key_sign_file_count -ne 1 ]; then
	echo -e "\n---\tERROR. Not Found key.pem file.\n"
fi

cert_sign_file_count=$(ls -l $HOME/Keys/developer-$sign_profile-release/cert.pem  2>/dev/null | wc -l)

if [ $cert_sign_file_count -ne 1 ]; then
	echo -e "\n---\tERROR. Not Found cert.pem file.\n"
fi

rpm_list=$(ls RPMS/*.rpm -la | awk '{print $10}' | cut -d'/' -f2)

echo -e "\n***\tSigning by $sign_profile profile.\n"

for rpm in $rpm_list
do
    res=$(rpmsign-external sign -k $HOME/Keys/developer-$sign_profile-release/key.pem -c $HOME/Keys/developer-$sign_profile-release/cert.pem RPMS/$rpm)
    if [[ `echo $res | grep "*Signed ( 1 / 1 )*"` -ne 0 ]] ; then
        echo "\n---\tPackage $rpm isn't signed! Exit.\n"
        exit 1
    fi
done

echo -e "\n***\tCheck validation.\n"
rpm-validator -p $sign_profile RPMS/*.rpm
if [[ $? -ne 0 ]]; then
	echo -e "\n---\tERROR. error validation.\n"
	#exit 1
fi

if [ -z "$install_device" ]; then
	echo -e "\n***\tOnly build and sign packages.\n"
	exit 0
fi

for rpm in $rpm_list
do
    echo -e "\n***\tDeploy package $rpm.\n"
    rpm_name=$(basename $rpm | cut -d '-' -f 1)
    if [[ $package_manager =~ 'apm' ]]; then
		reply=$(ssh -t $install_device "gdbus call --system --dest ru.omp.APM --object-path /ru/omp/APM --method ru.omp.APM.GetPackage \"$rpm_name\"")
		if [[ $reply =~ 'certificate.id' ]]; then
			reply=$(ssh -t $install_device "gdbus call --system --dest ru.omp.APM --object-path /ru/omp/APM --method ru.omp.APM.Remove \"$rpm_name\" \"{'':<false>}\"")
			if [[ $reply =~ 'Error' ]]; then
				echo -e "\n---\tERROR. Remove package.\n"
				exit 1
			fi    	
	    fi
	fi
    scp RPMS/$rpm $install_device:~
    if [[ $package_manager =~ 'apm' ]]; then
    	echo -e "\n***\taurora package manager set.\n"
    	reply=$(ssh -t $install_device "gdbus call --system --dest ru.omp.APM --object-path /ru/omp/APM --method ru.omp.APM.Install \"/home/defaultuser/$rpm\" \"{'ShowPrompt':<false>}\"")
    elif [[ $package_manager =~ 'pkcon' ]]; then
    	echo -e "\n***\tpkcon set. Enter devel-su password\n"
    	reply=$(ssh -t $install_device "devel-su pkcon install-local -y $rpm")
    elif [[ $package_manager =~ 'rpm' ]]; then
    	echo -e "\n***\trpm set. Enter devel-su password\n"
    	reply=$(ssh -t $install_device "devel-su rpm -ivh --force $rpm")
    else
    	echo -e "\n---\tERROR. Wrong package manager.\n"
		exit 1
    fi
    if [[ $reply =~ 'Error' ]]; then
    	echo -e "\n---\tERROR: $reply\n"
		exit 1
    fi
    echo -e "\n+++\tPackage $rpm installed successfully.\n" 
done
