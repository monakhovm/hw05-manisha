#!/usr/bin/env bash

#======BASIC FUNCTIONS==================
ask_user() {
    while true; do
        read -p "Enter your choice (y/Y for 'yes' and n/N for 'no'): " choice
        case $choice in
            [Yy]* ) return;;
            [Nn]* ) return 1;;
            * ) echo -e "Please answer y/Y/n/N.";;
        esac
    done
}

set_vars() {
    python=""
    package_manager=""
    packages=()
    common_packages=()
    mysql_dev_library=""
    unavailable_packages=()
    repos=()
    python_dir="$HOME/python3.7.2"
    delay=0
}

set_colors() {
    # Set colors
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    BLUE='\033[0;94m'
    YELLOW='\033[0;33m'
    NC='\033[0m' # No Color

    echo -n "Setting colors..."
    sleep $delay
    echo -e "${GREEN}OK!${NC}"
}

get_package_manager() {
    # Get actual package manager and set it to $package_manager variable
    echo -en "${BLUE}Understanding current package manager...${NC}"
    sleep $delay
    if command -v apt &>/dev/null; then
        package_manager="apt"
        echo -e "${GREEN}OK!${NC}"
        return
    elif command -v dnf &>/dev/null; then
        package_manager="dnf"
        echo -e "${GREEN}OK!${NC}"
        return
    elif command -v yum &>/dev/null; then
        package_manager="yum"
        echo -e "${GREEN}OK!${NC}"
        return
    # If package manager is not in list apt, yum, dnf print out message
    else
        echo -e "${RED}Failed!${NC}"
        echo -e "${RED}Unsupported package manager!${NC}"
        echo -e "It seems you ran the script on unsupported linux distro."
        echo -e "Its a pitty but you have to install all dependencies manually."
        echo -e "Get actual dependencies list from README.md file and install it."
        echo -e "And then run this script with '${YELLOW}--no-install${NC}' parameter"
        sleep $delay
        exit 1
    fi
}
#======BASIC FUNCTIONS==================


#======CHECK TOOLS======================
check_python_version() {
    echo -en "${BLUE}Checking installed python version...${NC}"
    if command -v python3 &>/dev/null; then
        python_version_full=$(python3 -V)
        python_version_major=$(echo $python_version_full | cut -d '.' -f 1)
        python_version_minor=$(echo $python_version_full | cut -d '.' -f 2)
        if [[ "$python_version_major$python_version_minor" == "37" ]]; then
            skip_python_installation=1
            python="python3"
        fi
        downloader="python3"
        sleep $delay
        echo -e "${GREEN}OK!${NC}"
    else
        sleep $delay
        echo -e "${RED}Failed!${NC}"
        sleep $delay
    fi
}

check_downloader() {
    echo -en "${BLUE}Checking any download tool...${NC}"
    sleep $delay
    if [[ -z $downloader ]]; then
        if command -v wget &>/dev/null; then
            downloader=wget
            echo -e "${GREEN}OK!${NC}"
            return
        elif command -v curl &>/dev/null; then
            downloader=curl
            echo -e "${GREEN}OK!${NC}"
            return
        fi
        [ -z $downloader ] && echo -e "${RED}Failed!${NC}"
    else
        echo -e "${GREEN}OK!${NC}"
        return
    fi
}

set_common_packages() {
    if [[ -z $downloader ]]; then
        if [ "--no-install" != "$1" ]; then
            echo -e "It seems you do not have any tool to download required version of python."
            echo -e "If you want to continue you should install ${YELLOW}wget${NC} or ${YELLOW}curl${NC} to download python."

            local future_downloader=""

            if [ "$package_manager" == "apt" ]; then
                if apt-cache madison wget &>/dev/null; then
                    future_downloader=wget
                    echo -e "Do you want to install ${YELLOW}$future_downloader${NC} and continue running of manisha's-application?"
                elif apt-cache madison curl &>/dev/null; then
                    future_downloader=curl
                    echo -e "Do you want to install ${YELLOW}$future_downloader${NC} and continue running of manisha's-application?"
                fi
            elif [ "$package_manager" == "dnf" ] || [ "$package_manager" == "yum" ]; then
                if $package_manager list wget &>/dev/null; then
                    future_downloader=wget
                    echo -e "Do you want to install ${YELLOW}$future_downloader${NC} and continue running of manisha's-application?"
                elif $package_manager list curl &>/dev/null; then
                    future_downloader=curl
                    echo -e "Do you want to install ${YELLOW}$future_downloader${NC} and continue running of manisha's-application?"
                fi
            fi

            if ask_user; then
                echo -en "${BLUE}Adding $future_downloader to install list...${NC}"
                downloader=$future_downloader
                sleep $delay
                echo -e "${GREEN}OK!${NC}"
            else
                sleep $delay
                echo -e "${RED}Failed!${NC}"
                echo -e "${YELLOW}Script can not run further without proper tools. User cancelation. Exitting... ${NC}"
                sleep $delay
                exit 1
            fi

            common_packages+=("$downloader")
        fi
    fi

    echo -en "${BLUE}Forming common tools list...${NC}"
    if ! command -v tar &>/dev/null; then
        common_packages+=("tar")
    fi
    if ! command -v gcc &>/dev/null; then
        common_packages+=("gcc")
    fi
    if ! command -v make &>/dev/null; then
        common_packages+=("make")
    fi
    if ! command -v git &>/dev/null; then
        common_packages+=("git")
    fi
    if ! command -v sed &>/dev/null; then
        common_packages+=("sed")
    fi
    
    echo -e "${GREEN}OK!${NC}"
}

get_dev_libraries() {
    if [ "$package_manager" == "apt" ]; then
    
        mysql_dev_library="libmysqlclient-dev"
        python_dev="python3-dev"

        distro=$(grep -hPo '^ID=\K[^=]+' /etc/*-release)
        distro_version=$(grep -hoP '^VERSION_ID="\K\d+' /etc/*-release)

        case $distro in
            debian)
                case $distro_version in
                    12) 
                        mysql_dev_library="default-libmysqlclient-dev"
                        ;;
                esac
            ;;

            ubuntu)
                return
                ;;

            *)
                # WARNING
                echo -e "${RED}==Warning!${NC}"
                ;;
        esac
    
    elif [[ "$package_manager" == "dnf" || "$package_manager" == "yum" ]]; then

        python_dev="python3-devel"
        mysql_dev_library="mysql-devel"
    
        distro=$(grep -hPo '^ID="\K[^"]+' /etc/*-release)
        distro_version=$(grep -hoP '^VERSION_ID="\K\d' /etc/*-release)
    
        case $distro in
            almalinux | centos | rocky | ol)
                case $distro_version in
                    7) 
                        mysql_dev_library="mariadb-devel"
                        ;;
                    8)
                        python_dev="python36-devel"
                        ;;
                    9) 
                        if $distro == "ol"; then
                            repos+=("--enablerepo=ol9_codeready_builder")
                        else
                            repos+=("--enablerepo=crb")
                        fi
                        ;;
                esac
            ;;

            *)
                # WARNING
                echo -e "${RED}Warning!${NC}"
                ;;
        esac
    fi

}

check_dependencies_list() {
    
    packages=()
    unavailable_packages=()

    echo -e "${BLUE}Checking required dependencies...${NC}"

    required_dependencies=("$mysql_dev_library" "$python_dev")

    if [ "$package_manager" == "apt" ]; then
        # From documentation
        required_dependencies+=("build-essential" "gdb" "lcov" "pkg-config" "libbz2-dev" "libffi-dev" "libgdbm-dev" "libgdbm-compat-dev" "liblzma-dev" "libncurses5-dev" "libreadline-dev" "libsqlite3-dev" "libssl-dev" "lzma" "lzma-dev" "tk-dev" "uuid-dev" "zlib1g-dev")
    else
        # From documentation
        required_dependencies+=("gcc-c++" "gdb" "bzip2-devel" "libffi-devel" "openssl-devel" "libuuid-devel" "zlib-devel")
    fi

    required_dependencies+=(${common_packages[@]})

    for package in "${required_dependencies[@]}"; do

        echo -n "Checking package $package..."
    
        if [ "$package_manager" == "apt" ]; then
            if ! dpkg-query -W -f='${Status}' $package 2>/dev/null | grep -q "ok installed"; then
                if ! apt-cache madison $package &>/dev/null; then
                    echo -e "${RED} unavailable!${NC}"
                    unavailable_packages+=$package
                else
                    packages+=("$package")
                    echo -e "${YELLOW} absent${NC}"
                fi
            else
                echo -e "${GREEN} installed${NC}"                
            fi
            
        elif [ "$package_manager" == "dnf" ] || [ "$package_manager" == "yum" ]; then
            if ! rpm -q $package &>/dev/null; then
                if ! $package_manager list $repos $package &>/dev/null; then
                    echo -e "${RED} unavailable!${NC}"
                    unavailable_packages+=("$package")
                else
                    packages+=("$package")
                    echo -e "${YELLOW} absent${NC}"
                fi
            else
                echo -e "${GREEN} installed${NC}" 
            fi
        fi
    done

    if [ ${#unavailable_packages[@]} -gt 0 ]; then
        sleep $delay
        echo -e "${RED}Yep.${NC}"
        sleep $delay
        echo -e "Sorry but some dependencies are not available for your system."
        echo -e "Script can not run further."
        echo -e "Its a pitty but you have to install theese dependencies manually."
        echo -e "Get actual dependencies list from README.md file and install those are unavailable."
        echo -e "Then run this script again."
        echo -e "If you will resolve ALL dependencies you can run script with '${YELLOW}--no-install${NC}' parameter to skip packages installation"
        exit 1
    else
        [ ${#packages[@]} -eq 0 ] && echo -e "${GREEN}All ok!${NC}" || echo -e "${RED}There are missing dependencies${NC}"
        [ ${#packages[@]} -gt 0 ] && [ "--no-install" == "$1" ] && exit 1
        return
    fi
}
#======CHECK TOOLS======================


#======DEPENDENCIES INSTALLATION========
install_packages() {
    if [ ${#packages[@]} -gt 0 ]; then
        echo -e "${BLUE}Installing packages...${NC}"
        sleep $delay
        
        echo -e "Absent dependecies are detected. They are: "
        
        for package in "${packages[@]}"; do
            echo -e "${YELLOW}$package${NC}"
        done

        echo -e "Do you want to install it?\nNOTICE: You might be need superuser permissions to install additional packages."

        if ask_user; then
            local install_command="install"
            local parameter="-y"
            if [ $UID -ne 0 ]; then
                sudo_var="sudo"
            fi
            full_command="$sudo_var $package_manager $install_command $repos $parameter ${packages[*]}"
            echo -e "${YELLOW}Installing required packages: ${BLUE}${packages[*]}${NC}"
            eval $full_command
            if [ $? -ne 0 ]; then
                echo -e "${RED}Package installation failed. Please check the output above for more details.${NC}"
                exit 1
            else
                echo -e "${GREEN}All required packages installed successfully.${NC}"
            fi

            if [ $UID -ne 0 ]; then
                sudo -k
            fi
        
        else
            echo -e "${YELLOW}Script can not run further without proper tools. User cancelation. Exiting... ${NC}"
            sleep $delay
            exit 1
        fi
    else
        sleep $delay
        echo -e "${GREEN}All required packages already installed.${NC}"
    fi
}
#======DEPENDENCIES INSTALLATION========


#======PYTHON INSTALLATION==============
get_python() {
    if [[ -z $pyhthon ]]; then
        echo -en "${BLUE}Downloading python...${NC}"
        case $downloader in
            wget)
                wget -q https://www.python.org/ftp/python/3.7.2/Python-3.7.2.tgz
                ;;
            curl)
                curl -s https://www.python.org/ftp/python/3.7.2/Python-3.7.2.tgz -o Python-3.7.2.tgz
                ;;
            python3)
                python3 -c "import urllib.request; response = urllib.request.urlopen('https://www.python.org/ftp/python/3.7.2/Python-3.7.2.tgz'); open('Python-3.7.2.tgz', 'wb').write(response.read())"
                ;;
            *)
                echo -e "${RED}Failed!${NC}"; 
                sleep $delay
                exit 1;;
        esac

        if [ $? -ne 0 ]; then
            echo -e "${RED}Failed!${NC}"
            exit 1
        else
            echo -e "${GREEN}OK!${NC}"
        fi
    fi
}

build_python() {
    if [[ -z $python ]]; then
        echo -en "${BLUE}Unpacking python...${NC}" 
        tar -xf Python-3.7.2.tgz

        if [ $? -ne 0 ]; then
            echo -e "${RED}Failed!${NC}"
            exit 1
        else
            echo -e "${GREEN}OK!${NC}"
        fi

        cd Python-3.7.2

        echo -e "${BLUE}Configuring installation...${NC}"
        ./configure --prefix $python_dir --without-ensurepip
        echo -en "${BLUE}Configuring installation...${NC}"
        sleep $delay

        if [ $? -ne 0 ]; then
            echo -e "${RED}Failed!${NC}"
            exit 1
        else
            echo -e "${GREEN}OK!${NC}"
        fi

        echo -e "${BLUE}Making installation...${NC}"
        make -j $(nproc)
        make install
        echo -en "${BLUE}Making installation...${NC}"
        sleep $delay

        if [ $? -ne 0 ]; then
            echo -e "${RED}Failed!${NC}"
            exit 1
        else
            python="$python_dir/bin/python3"
            echo -e "${GREEN}OK!${NC}"
        fi
    else 
        return
    fi
}
#======PYTHON INSTALLATION==============


#======PIP INSTALLATION=================
install_pip() {
    if ! $python -m pip &>/dev/null; then
        echo -en "${BLUE}Downloading pip...${NC}" 
        case $downloader in
            wget* )
                wget -q https://bootstrap.pypa.io/get-pip.py;;
            curl* )
                curl -s https://bootstrap.pypa.io/get-pip.py -o get-pip.py;;
            python3* )
                python3 -c "import urllib.request; response = urllib.request.urlopen('https://bootstrap.pypa.io/get-pip.py'); open('get-pip.py', 'wb').write(response.read())";;
            * )
                echo -e "${RED}Failed!${NC}"; echo -e "Something went wrong. Unable to download pip."; exit 1;;
        esac

        if [ $? -ne 0 ]; then
            echo -e "${RED}Failed!${NC}"
            echo -e "${RED}Pip download failed. Please check the output above for more details.${NC}"
            exit 1
        else
            echo -e "${GREEN}OK!${NC}"
        fi

        echo -e "${BLUE}Installing pip...${NC}"
        $python get-pip.py

        if [ $? -ne 0 ]; then
            echo -e "${RED}Failed!${NC}"
            echo -e "${RED}Pip install failed. Please check the output above for more details.${NC}"
            exit 1
        else
            echo -en "${BLUE}Installing pip...${NC}"
            echo -e "${GREEN}OK!${NC}"
        fi
    fi
}
#======PIP INSTALLATION=================


#======VENV FUNCTIONS===================
create_virtualenv() {
    if ! $python -m virtualenv &>/dev/null; then
        echo -e "${BLUE}Installing virtual environment...${NC}"
        $python -m pip install virtualenv
        echo -en "${BLUE}Installing virtual environment...${NC}"
        if [ $? -ne 0 ]; then
            echo -e "${RED}Failed!${NC}"
            exit 1
        else
            echo -e "${GREEN}OK!${NC}"
        fi
    fi

    echo -e "${BLUE}Making virtual environment...${NC}"
    $python -m virtualenv $HOME/venv
    echo -en "${BLUE}Making virtual environment...${NC}"
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed!${NC}"
        exit 1
    else
        echo -e "${GREEN}OK!${NC}"
    fi
}

activate_virtualenv() {
    source $HOME/venv/bin/activate
    echo -en "${BLUE}Activating virtual environment...${NC}"
    sleep $delay
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed!${NC}"
        exit 1
    else
        echo -e "${GREEN}OK!${NC}"
    fi
}
#======VENV FUNCTIONS===================


#======APP SETUP========================
get_django_settings_from_env() {
    # Get djanfo variables from .env
    echo -en "${BLUE}Reading .env file...${NC}"
    sleep $delay
    source $HOME/.env
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed!${NC}"
        echo -e "${YELLOW}Script can run application without variables set in .env file. Read instructions in README.md please.${NC}"
        exit 1
    else
        echo -e "${GREEN}OK!${NC}"
    fi
}

get_application_code() {
    echo -e "${BLUE}Downloading application code...${NC}"
    git clone https://github.com/Manisha-Bayya/simple-django-project.git --branch=master $HOME/simple-django_project
    echo -en "${BLUE}Downloading application code...${NC}"
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed!${NC}"
        exit 1
    else
        echo -e "${GREEN}OK!${NC}"
    fi
}

install_requirements() {
    cd $HOME/simple-django_project
    $python -m pip install setuptools==60.10.0 wheel==0.37.1 # From world's history
    $python -m pip install -r requirements.txt
}

# edit_files() {}
#======APP SETUP========================


#======APP RUN==========================
# make_migrations() {}
# run_server() {}
#======APP RUN==========================

basic_functions() {
    set_vars
    set_colors
    get_package_manager
}

check_tools() {
    check_python_version
    check_downloader
    set_common_packages $1
    get_dev_libraries
    check_dependencies_list $1
}

dependecies_installation() {
    install_packages
}

python_installation() {
    get_python 
    build_python
}

pip_installation() {
    install_pip
}

venv_functions() {
    create_virtualenv
    activate_virtualenv
}

app_setup() {
    get_django_settings_from_env
    get_application_code
    install_requirements
    # edit_files
}

app_run() {
    # make_migrations
    # run_server
    return
}

main() {
    basic_functions
    check_tools $1
    if [ "--no-install" != "$1" ]; then
        dependecies_installation
    fi
    if [ "--no-python" != "$1" ]; then
        python_installation
        pip_installation
        venv_functions
        app_setup
        app_run
    fi
}

main $1

#TODO:
#       Add checks on $skip_python_installation
#       fix problems
#       setup application
#       run application
#       add --no-install
#       add --no-python?

##      Print list of unavailable packages