{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:{
    programs.lazygit = {
      enable = true;
      settings = {
        keybinding = {
          universal = {
            quit="q";
            quit-alt1="<c-c>";
            return="<esc>";
            quitWithoutChangingDirectory="Q";
            togglePanel="<tab>";
            prevItem="<up>";
            nextItem="<down>";
            prevItem-alt="i";
            nextItem-alt="e";
            prevPage=",";
            nextPage=".";
            scrollLeft="N";
            scrollRight="O";
            gotoTop="<";
            gotoBottom=">";
            toggleRangeSelect="v";
            rangeSelectDown="<s-down>";
            rangeSelectUp="<s-up>";
            prevBlock="<left>";
            nextBlock="<right>";
            prevBlock-alt="n";
            nextBlock-alt="o";
            nextBlock-alt2="<tab>";
            prevBlock-alt2="<backtab>";
            nextMatch="h";
            prevMatch="H";
            startSearch="/";
            optionMenu="<disabled>";
            optionMenu-alt1="?";
            select="<space>";
            goInto="<enter>";
            confirm="<enter>";
            confirmInEditor="<a-enter>";
            remove="d";
            new="h";
            edit="j";
            openFile="y";
            scrollUpMain="<pgup>";
            scrollDownMain="<pgdown>";
            scrollUpMain-alt1="I";
            scrollDownMain-alt1="E";
            scrollUpMain-alt2="<c-u>";
            scrollDownMain-alt2="<c-d>";
            executeShellCommand=":";
            createRebaseOptionsMenu="m";
            pushFiles="P";
            pullFiles="p";
            refresh="R";
            createPatchOptionsMenu="<c-p>";
            nextTab="]";
            prevTab="[";
            nextScreenMode="+";
            prevScreenMode="_";
            undo="z";
            redo="<c-z>";
            filteringMenu="<c-s>";
            diffingMenu="W";
            diffingMenu-alt="<c-e>";
            copyToClipboard="<c-o>";
            openRecentRepos="<c-r>";
            submitEditorText="<enter>";
            extrasMenu="@";
            toggleWhitespaceInDiffView="<c-w>";
            increaseContextInDiffView="}";
            decreaseContextInDiffView="{";
            increaseRenameSimilarityThreshold=")";
            decreaseRenameSimilarityThreshold="(";
            openDiffTool="<c-t>";
            jumpToBlock = ["1" "2" "3" "4" "5"];
          };
          status = {
checkForUpdate="k";
recentRepos="<enter>";
allBranchesLogGraph="a";
            };
files = {
commitChanges="c";
commitChangesWithoutHook="w";
amendLastCommit="A";
commitChangesWithEditor="C";
findBaseCommitForFixup="<c-f>";
confirmDiscard="x";
ignoreFile="u";
refreshFiles="r";
stashAllChanges="s";
viewStashOptions="S";
toggleStagedAll="a";
viewResetOptions="D";
fetch="f";
toggleTreeView="`";
openMergeTool="M";
openStatusFilter="<c-b>";
copyFileInfoToClipboard="l";
  };
  branches = {
createPullRequest="y";
viewPullRequestOptions="Y";
copyPullRequestURL="<c-y>";
checkoutBranchByName="c";
forceCheckoutBranch="F";
rebaseBranch="r";
renameBranch="R";
mergeIntoCurrentBranch="M";
viewGitFlowOptions="u";
fastForward="f";
createTag="T";
pushTag="P";
setUpstream="k";
fetchRemote="f";
sortOrder="s";
    };
worktrees = {
viewWorktreeOptions="w";
  };
  commits = {
squashDown="s";
renameCommit="r";
renameCommitWithEditor="R";
viewResetOptions="g";
markCommitAsFixup="f";
createFixupCommit="F";
squashAboveCommits="S";
moveDownCommit="<c-j>";
moveUpCommit="<c-k>";
amendToCommit="A";
resetCommitAuthor="a";
pickCommit="p";
revertCommit="t";
cherryPickCopy="C";
pasteCommits="V";
markCommitAsBaseForRebase="B";
tagCommit="T";
checkoutCommit="<space>";
resetCherryPick="<c-R>";
copyCommitAttributeToClipboard="l";
openLogMenu="<c-l>";
openInBrowser="y";
viewBisectOptions="b";
startInteractiveRebase="u";
    };
amendAttribute = {
resetAuthor="a";
setAuthor="A";
addCoAuthor="c";
  };
  stash = {
popStash="g";
renameStash="r";
    };
commitFiles = {

checkoutCommitFile="c";
  };
  main = {
toggleSelectHunk="a";
pickBothHunks="b";
editSelectHunk="J";

    };
submodules = {
init="u";
update="k";
bulkMenu="b";

  };
  commitMessage = {
commitMenu="<c-o>";
    };
        };
      };
    };
}
