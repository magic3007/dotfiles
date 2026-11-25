# Add every private key under ~/.ssh to the ssh agent.
if find "${HOME}/.ssh" -name "id_*" -print -quit | grep -q .; then
  for possiblekey in ${HOME}/.ssh/id_*; do
    if grep -q PRIVATE "$possiblekey" 2>/dev/null; then
      ssh-add "$possiblekey" 2>/dev/null
    fi
  done
fi
