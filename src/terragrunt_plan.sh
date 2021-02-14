#!/bin/bash

function terragruntPlan {
  # Gather the output of `terragrunt plan`.
  echo "plan: info: planning Terragrunt configuration in ${tfWorkingDir}"
  planOutput=$(${tfBinary} ${tfRunAll} plan -input=false ${*} 2>&1)
  planExitCode=${?}
  planCommentStatus="Failed"

  # Exit code of 0 indicates success. Print the output and exit.
  if [ ${planExitCode} -eq 0 ]; then
    planCommentStatus="Success"
    echo "plan: info: successfully planned Terragrunt configuration in ${tfWorkingDir}"
    echo "${planOutput}"
    echo
    if echo "${planOutput}" | egrep '^-{72}$' &> /dev/null; then
        planOutput=$(echo "${planOutput}" | sed -n -r '/-{72}/,/-{72}/{ /-{72}/d; p }')
    fi
    planOutput=$(echo "${planOutput}" | sed -r -e 's/^  \+/\+/g' | sed -r -e 's/^  ~/~/g' | sed -r -e 's/^  -/-/g')
  fi

  # Exit code of !0 indicates failure.
  if [ ${planExitCode} -ne 0 ]; then
    echo "plan: error: failed to plan Terragrunt configuration in ${tfWorkingDir}"
    echo "${planOutput}"
    echo
  fi

  # Comment on the pull request if necessary.
  if [ "$GITHUB_EVENT_NAME" == "pull_request" ] && [ "${tfComment}" == "1" ]; then
    planCommentWrapper="#### \`${tfBinary} ${tfRunAll} plan\` ${planCommentStatus}
<details><summary>Show Output</summary>

\`\`\`
${planOutput}
\`\`\`

</details>

*Workflow: \`${GITHUB_WORKFLOW}\`, Action: \`${GITHUB_ACTION}\`, Working Directory: \`${tfWorkingDir}\`, Workspace: \`${tfWorkspace}\`*"

    planCommentWrapper=$(stripColors "${planCommentWrapper}")
    echo "plan: info: creating JSON"
    planPayload=$(echo "${planCommentWrapper}" | jq -R --slurp '{body: .}')
    planCommentsURL=$(cat ${GITHUB_EVENT_PATH} | jq -r .pull_request.comments_url)
    echo "plan: info: commenting on the pull request"
    echo "${planPayload}" | curl -s -S -H "Authorization: token ${GITHUB_TOKEN}" --header "Content-Type: application/json" --data @- "${planCommentsURL}" > /dev/null
  fi

  # https://github.community/t5/GitHub-Actions/set-output-Truncates-Multiline-Strings/m-p/38372/highlight/true#M3322
  planOutput="${planOutput//'%'/'%25'}"
  planOutput="${planOutput//$'\n'/'%0A'}"
  planOutput="${planOutput//$'\r'/'%0D'}"

  echo "::set-output name=tf_actions_plan_output::${planOutput}"
  exit ${planExitCode}
}
