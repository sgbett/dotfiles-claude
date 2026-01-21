#!/bin/bash
# Hook to remind Claude not to start implementing after ExitPlanMode

cat << 'EOF'
STOP. The plan has NOT been approved. Implementation has NOT been authorised.

You MUST wait for the user to explicitly say "start", "implement", "go ahead", or similar.

Do not write code. Do not create files. Do not make changes. Ask what the user wants to do next.
EOF

exit 0
