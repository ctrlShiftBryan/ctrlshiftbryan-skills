/zoom-out and explain what this PR does. build me an html explainer with visualizers that help me understand the PR. the explainer should give me manual verification instructions for verifying the app in the browser or command line cli so I can see the changes and ensure they didn't regress anything. Only include the most critical verification steps.

In the <head> of the generated HTML, include the Plannotator inject script so the published explainer can be annotated:
<script src="https://ctrlshiftbryan.github.io/plannotator-inject/inject.js"></script>

Near the top of the explainer, add a clickable link back to this PR: {{PR_URL}}

write the html file to {{EXPLAINER_PATH}}

After the file is written, publish it by running: __PUBLISH_CMD__
Do not stop after generating the file -- you must run the publish command so the explainer goes live and this check turns green.
