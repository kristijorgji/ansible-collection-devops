#!/usr/bin/env bash
# Idempotent HTTP-01 issuance. Skips when every domain already has a live lineage.
# PRE_HOOK runs once if any cert is missing. POST_HOOK always runs after issuance
# attempts so callers can restore a reverse proxy even on partial failure.
set -uo pipefail

LETSENCRYPT_PATH="${LETSENCRYPT_PATH:-/etc/letsencrypt/live}"

if [[ -z "${CERTBOT_ADMIN_EMAIL:-}" ]]; then
	echo "Missing required environment variable CERTBOT_ADMIN_EMAIL"
	exit 1
fi

DOMAINS=("$@")
if [[ ${#DOMAINS[@]} -eq 0 ]]; then
	echo "No domains given"
	exit 1
fi

echo "Required domains: ${DOMAINS[*]}"

NEEDS_CERT=0
for domain in "${DOMAINS[@]}"; do
	if ! compgen -G "${LETSENCRYPT_PATH}/${domain}*" >/dev/null; then
		NEEDS_CERT=1
		break
	fi
done

if [[ "${NEEDS_CERT}" -eq 0 ]]; then
	echo "All certificates already exist, nothing to do."
	exit 0
fi

extra=()
if [[ -n "${CERTBOT_ARGS:-}" ]]; then
	# shellcheck disable=SC2206
	read -r -a extra <<<"${CERTBOT_ARGS}"
fi

if [[ -n "${PRE_HOOK:-}" ]]; then
	echo -e "Executing pre hook [${PRE_HOOK}]\n"
	eval "${PRE_HOOK}"
fi

for domain in "${DOMAINS[@]}"; do
	echo -e "Creating certificate for ${domain}\n"
	if compgen -G "${LETSENCRYPT_PATH}/${domain}*" >/dev/null; then
		echo -e "Already exists, skipping\n"
		continue
	fi
	if ! certbot certonly --non-interactive \
		-d "${domain}" \
		--cert-name "${domain}" \
		-m "${CERTBOT_ADMIN_EMAIL}" \
		--agree-tos \
		"${extra[@]}"; then
		echo -e "ERROR: Failed to create certificate for ${domain}\n"
	fi
done

MISSING_DOMAINS=()
for domain in "${DOMAINS[@]}"; do
	if ! compgen -G "${LETSENCRYPT_PATH}/${domain}*" >/dev/null; then
		MISSING_DOMAINS+=("${domain}")
	fi
done

if [[ -n "${POST_HOOK:-}" ]]; then
	echo -e "Executing post hook [${POST_HOOK}]\n"
	eval "${POST_HOOK}"
fi

if [[ ${#MISSING_DOMAINS[@]} -gt 0 ]]; then
	echo -e "\nERROR: Failed to create certificates for the following domains:\n"
	for domain in "${MISSING_DOMAINS[@]}"; do
		echo "  - ${domain}"
	done
	echo -e "\nPlease check the certbot logs and retry later.\n"
	exit 1
fi
