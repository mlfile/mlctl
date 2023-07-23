#!/bin/bash
set -e

#############################################################################
#                                                                           #
# Copyright mlfile contributors.                                            #
#                                                                           #
# Licensed under the Apache License, Version 2.0 (the "License"); you may   #
# not use this file except in compliance with the License. You may obtain   #
# a copy of the License at:                                                 #
#                                                                           #
# http://www.apache.org/licenses/LICENSE-2.0                                #
#                                                                           #
# Unless required by applicable law or agreed to in writing, software       #
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT #
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the  #
# License for the specific language governing permissions and limitations   #
# under the License.                                                        #
#                                                                           #
#############################################################################

PARAMS=""
while (( "$#" )); do
    case "$1" in
        -k|--pypi-key)
            KARG=$2
            shift 2
            ;;
        --) # end argument parsing
            shift
            break
            ;;
        -*|--*=) # unsupported flags
            echo "Error: Unsupported flag $1" >&2
            echo "Please use ./pypi_publish.sh [-k <pypi key> | --pypi-key <pypi key>]" >&2
            exit 1
            ;;
        *) # preserve positional arguments
        PARAMS="$PARAMS $1"
        shift
        ;;
    esac
done

#
# Initial variables
#

all_published_versions=$(curl -L https://pypi.python.org/pypi/mlfile/json | jq -r '.releases' | jq 'keys[]')
current_mlfile_version=$(cat src/setup.py | grep "_REVISION = '" | cut -d "'" -f 2)

publish="1"

#
# Check all the current published versions and if the
# packaged to be created has a different version, then
# we publish it to Galaxy Ansible
#
echo ""
echo "Checking versions:"
for ver in $all_published_versions; do
    echo "--"
    echo "Published: "$ver
    echo "Built: "$current_mlfile_version
    echo ""
    if [[ $ver == \"$current_mlfile_version\" ]]; then
        echo "The current version $current_mlfile_version is already published"
        echo "Proceed to update the setup.py file with a newer version"
        echo "After the version change, when the commit is merged, then the package"
        echo "will be published automatically."
        publish="0"
    fi
done

cd ./src
python3 setup.py sdist
twine check dist/*

if [ "$publish" == "1" ]; then
    echo 'This version is not published, publishing!...'


cat <<EOF > ~/.pypirc
[distutils]
index-servers =
    pypi
    testpypi
    mlfile

[pypi]
username = __token__

[testpypi]
username = __token__

[mlfile]
repository = https://upload.pypi.org/legacy/
username = __token__
password = $KARG
EOF

    twine upload --verbose --repository mlfile dist/*
fi
