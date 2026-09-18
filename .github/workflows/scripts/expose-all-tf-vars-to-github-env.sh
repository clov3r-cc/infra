#!/usr/bin/env bash
set -euo pipefail

: "${GITHUB_ENV:?GITHUB_ENV must be set}"
: "${SECRETS_CONTEXT:?SECRETS_CONTEXT must be set}"

readonly variable_prefix='TF_VAR_'
temporary_directory=''
temporary_directory="$(mktemp -d)"
readonly temporary_directory
temporary_value_file="${temporary_directory}/value"
temporary_output_file="${temporary_directory}/output"

cleanup() {
  rm -f -- "${temporary_value_file}" "${temporary_output_file}"
  rmdir -- "${temporary_directory}"
}
trap cleanup EXIT

if ! jq -e 'type == "object"' <<<"${SECRETS_CONTEXT}" >/dev/null 2>&1; then
  printf '%s\n' 'SECRETS_CONTEXT must contain a JSON object' >&2
  exit 1
fi

entries="$(jq -c 'to_entries[]' <<<"${SECRETS_CONTEXT}")"
declare -A exported_variables=()

while IFS= read -r entry; do
  [[ -n "${entry}" ]] || continue

  key="$(jq -r '.key' <<<"${entry}")"
  [[ "${key}" == "${variable_prefix}"* ]] || continue

  variable_name="${key#"${variable_prefix}"}"
  variable_name="${variable_name,,}"

  if [[ ! "${variable_name}" =~ ^[a-z_][a-z0-9_]*$ ]]; then
    printf 'Invalid Terraform variable name derived from secret key: %s\n' "${key}" >&2
    exit 1
  fi

  if [[ -n "${exported_variables[${variable_name}]+x}" ]]; then
    printf 'Duplicate Terraform variable name: TF_VAR_%s\n' "${variable_name}" >&2
    exit 1
  fi
  exported_variables["${variable_name}"]=1

  if ! jq -e '.value | type == "string"' <<<"${entry}" >/dev/null 2>&1; then
    printf 'Secret value for %s must be a string\n' "${key}" >&2
    exit 1
  fi
  jq -j '.value' <<<"${entry}" >"${temporary_value_file}"

  delimiter_seed="$(sha256sum "${temporary_value_file}" | cut -c1-16)"
  delimiter="__GITHUB_ENV_${variable_name}_${delimiter_seed}"
  suffix=0
  while grep -Fqx -- "${delimiter}" "${temporary_value_file}"; do
    suffix=$((suffix + 1))
    delimiter="__GITHUB_ENV_${variable_name}_${delimiter_seed}_${suffix}"
  done

  {
    printf 'TF_VAR_%s<<%s\n' "${variable_name}" "${delimiter}"
    cat "${temporary_value_file}"
    if [[ ! -s "${temporary_value_file}" ]] || [[ "$(tail -c 1 "${temporary_value_file}" | od -An -t x1)" != *0a ]]; then
      printf '\n'
    fi
    printf '%s\n' "${delimiter}"
  } >>"${temporary_output_file}"
done <<<"${entries}"

cat "${temporary_output_file}" >>"${GITHUB_ENV}"
