#!/bin/bash
#
# To be run with the /system/build.prop (build.prop) and
# /vendor/build.prop (vendor-build.prop) from the stock
# ROM of a device you want to spoof values from

echo -e "system build.prop to custom.pif.json/.prop creator \
    \nby osm0sis @ xda-developers \
    \nand modified by Juleast @ https://github.com/juleast";

item() { echo -e "\n- $@"; }
die() { 
  echo -e "\n\n! $@"
  return
}
file_getprop() { grep "^$2=" "$1" 2>/dev/null | tail -n1 | cut -d= -f2-; }

main() {
  case $1 in
  json|prop) FORMAT=$1;;
  "") FORMAT=json;;
  esac;
  item "Using format: $FORMAT";

  [ ! -f build.prop ] && [ ! -f system-build.prop -o ! -f product-build.prop ] \
    && die "No build.prop files found in script directory";

  item "Parsing build.prop(s) ...";

  PRODUCT=$(file_getprop build.prop ro.product.name);
  DEVICE=$(file_getprop build.prop ro.product.device);
  MANUFACTURER=$(file_getprop build.prop ro.product.manufacturer);
  BRAND=$(file_getprop build.prop ro.product.brand);
  MODEL=$(file_getprop build.prop ro.product.model);
  FINGERPRINT=$(file_getprop build.prop ro.build.fingerprint);

  [ -z "$PRODUCT" ] && PRODUCT=$(file_getprop build.prop ro.product.system.name);
  [ -z "$DEVICE" ] && DEVICE=$(file_getprop build.prop ro.product.system.device);
  [ -z "$MANUFACTURER" ] && MANUFACTURER=$(file_getprop build.prop ro.product.system.manufacturer);
  [ -z "$BRAND" ] && BRAND=$(file_getprop build.prop ro.product.system.brand);
  [ -z "$MODEL" ] && MODEL=$(file_getprop build.prop ro.product.system.model);
  [ -z "$FINGERPRINT" ] && FINGERPRINT=$(file_getprop build.prop ro.system.build.fingerprint);

  case $DEVICE in
    generic) die "Generic /system/build.prop values found, rename to system-build.prop and add product-build.prop";;
  esac;

  [ -z "$PRODUCT" ] && PRODUCT=$(file_getprop product-build.prop ro.product.product.name);
  [ -z "$DEVICE" ] && DEVICE=$(file_getprop product-build.prop ro.product.product.device);
  [ -z "$MANUFACTURER" ] && MANUFACTURER=$(file_getprop product-build.prop ro.product.product.manufacturer);
  [ -z "$BRAND" ] && BRAND=$(file_getprop product-build.prop ro.product.product.brand);
  [ -z "$MODEL" ] && MODEL=$(file_getprop product-build.prop ro.product.product.model);
  [ -z "$FINGERPRINT" ] && FINGERPRINT=$(file_getprop product-build.prop ro.product.build.fingerprint);

  if [ -z "$FINGERPRINT" ]; then
    if [ -f build.prop ]; then
      die "No fingerprint found, use a /system/build.prop to start";
    else
      die "No fingerprint found, unable to continue";
    fi;
  fi;
  echo "$FINGERPRINT";

  LIST="PRODUCT DEVICE MANUFACTURER BRAND MODEL FINGERPRINT";

  item "Parsing build UTC date ...";
  UTC=$(file_getprop build.prop ro.build.date.utc);
  [ -z "$UTC" ] && UTC=$(file_getprop system-build.prop ro.build.date.utc);
  date -u -d @$UTC;

  if [ "$UTC" -gt 1521158400 ]; then
    item "Build date newer than March 2018, adding SECURITY_PATCH ...";
    SECURITY_PATCH=$(file_getprop build.prop ro.build.version.security_patch);
    [ -z "$SECURITY_PATCH" ] && SECURITY_PATCH=$(file_getprop system-build.prop ro.build.version.security_patch);
    LIST="$LIST SECURITY_PATCH";
    echo "$SECURITY_PATCH";
  fi;

  item "Parsing build first API level ...";
  FIRST_API_LEVEL=$(file_getprop vendor-build.prop ro.product.first_api_level);
  [ -z "$FIRST_API_LEVEL" ] && FIRST_API_LEVEL=$(file_getprop vendor-build.prop ro.board.first_api_level);
  [ -z "$FIRST_API_LEVEL" ] && FIRST_API_LEVEL=$(file_getprop vendor-build.prop ro.board.api_level);

  if [ -z "$FIRST_API_LEVEL" ]; then
    [ ! -f vendor-build.prop ] && die "No first API level found, add vendor-build.prop";
    item "No first API level found, falling back to build SDK version ...";
    [ -z "$FIRST_API_LEVEL" ] && FIRST_API_LEVEL=$(file_getprop build.prop ro.build.version.sdk);
    [ -z "$FIRST_API_LEVEL" ] && FIRST_API_LEVEL=$(file_getprop build.prop ro.system.build.version.sdk);
    [ -z "$FIRST_API_LEVEL" ] && FIRST_API_LEVEL=$(file_getprop system-build.prop ro.build.version.sdk);
    [ -z "$FIRST_API_LEVEL" ] && FIRST_API_LEVEL=$(file_getprop system-build.prop ro.system.build.version.sdk);
    [ -z "$FIRST_API_LEVEL" ] && FIRST_API_LEVEL=$(file_getprop vendor-build.prop ro.vendor.build.version.sdk);
    [ -z "$FIRST_API_LEVEL" ] && FIRST_API_LEVEL=$(file_getprop product-build.prop ro.product.build.version.sdk);
  fi;
  echo "$FIRST_API_LEVEL";

  if [ "$FIRST_API_LEVEL" -gt 32 ]; then
    item "First API level 33 or higher, resetting to 32 ...";
    FIRST_API_LEVEL=32;
  fi;
  LIST="$LIST FIRST_API_LEVEL";

  if [ -f custom.pif.$FORMAT ]; then
    item "Removing existing custom.pif.$FORMAT ...";
    rm -f custom.pif.$FORMAT;
  fi;

  item "Writing new custom.pif.$FORMAT ...";
  [ "$FORMAT" == "json" ] && echo '{' | tee -a custom.pif.json;
  for PROP in $LIST; do
    case $FORMAT in
      json) eval echo '\ \ \"$PROP\": \"'\$$PROP'\",';;
      prop) eval echo $PROP=\$$PROP;;
    esac;
  done | sed '$s/,//' | tee -a custom.pif.$FORMAT;
  [ "$FORMAT" == "json" ] && echo '}' | tee -a custom.pif.json;

  echo
  echo "Done!"
  cd ../
}

scan_for_build_prop() {
  local base_dir=$1

  # First, prioritize the 'system' directory
  local system_build_prop="$base_dir/system/build.prop"
  if [ -f "$system_build_prop" ]; then
    echo "$system_build_prop"
    return 0
  fi

  # Next, check the 'vendor' directory
  local vendor_build_prop="$base_dir/vendor/build.prop"
  if [ -f "$vendor_build_prop" ]; then
    echo "$vendor_build_prop"
    return 0
  fi

  # If not found in 'system' or 'vendor', search other directories
  local found_files=$(find "$base_dir" -type f -name "build.prop" ! -path "$system_build_prop" ! -path "$vendor_build_prop")

  if [ -z "$found_files" ]; then
    return 1
  fi

  echo "$found_files" | head -n 1  # Return the first found file path
}



# Modified search_build_prop function to include scanning with prioritization
search_build_prop() {
  read -e -p "Enter the directory path to search for build.prop: " base_dir
  if [ ! -d "$base_dir" ]; then
    echo "Directory not found: $base_dir"
    return 1
  fi

  local selected_build_prop
  if ! selected_build_prop=$(scan_for_build_prop "$base_dir"); then
    echo "No suitable build.prop file found. Please check the directory and try again."
    return 1
  fi

  echo "Using $selected_build_prop for processing."
  cp "$selected_build_prop" ./
  main  # Call main function to process the found build.prop
}

generate_options() {
  local i=1
  for dir in "${dir_arr[@]}"; do
    echo "$i. $dir"
    ((i++))
  done
  echo "$i. search"
}

# Process user selection with dynamic option numbering
process_selection() {
  local arr_index=$1
  local total_options=$(( ${#dir_arr[@]} + 1 ))

  if [ "$arr_index" -eq "$total_options" ]; then
    search_build_prop || exit 1
  elif [ "$arr_index" -gt 0 ] && [ "$arr_index" -le "${#dir_arr[@]}" ]; then
    local selected_dir=${dir_arr[$((arr_index - 1))]}
    if [ "$selected_dir" = "./.git" ]; then
      echo "This is a .git folder. Rerun the script."
      exit 1
    fi
    cd "$shdir"
    cd "$selected_dir"
    main
  else
    echo "Invalid option selected. Exiting..."
    exit 1
  fi
}

# Main execution
case $0 in
  *.sh) shdir="$0";;
     *) shdir="$(lsof -p $$ 2>/dev/null | grep -o '/.*gen_pif_custom.sh$')";;
esac;
shdir=$(dirname "$(readlink -f "$shdir")");

readarray -t dir_arr < <(find . -maxdepth 1 -type d -not -path "./.git")
generate_options

read -p "Enter number: " arr_index
if [ -z "$arr_index" ]; then
  echo "No option selected."
  exit 1
fi

process_selection "$arr_index"
