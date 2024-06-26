#!/bin/bash

SCRIPT_FILE="$0"
if [ -L "${SCRIPT_FILE}" ]; then
   SCRIPT_DIR="$(dirname "$(readlink -f "${SCRIPT_FILE}")")"
else
   SCRIPT_DIR="$(cd "$(dirname "${SCRIPT_FILE}")" && pwd)"
fi
CURRENT_DIR="${PWD}"

PROJECT=""
BRANCH=""
UNDO=false
VERBOSE=false

source ${SCRIPT_DIR}/../../common/bin/logging.sh
source ${SCRIPT_DIR}/../../common/bin/dirs.sh
if [ -f ${SCRIPT_DIR}/custom_repos.sh ]; then
   source ${SCRIPT_DIR}/custom_repos.sh
else
   source ${SCRIPT_DIR}/repos.sh
fi

#
# Function for handling script exit
#
on_exit() {
   cd "${CURRENT_DIR}"
}

#
# Function for printing script usage information
#
print_usage() {
   echo "Usage: pull [-h|--help] [-v|--verbose] [-u|--undo] [-d|--develop] [-b|--branch <branch>] [-p|--project <project>] [--all]"
   echo -e "\nArguments:"
   echo -e "\t-h or --help\t\t\t\t\t\tPrint this help."
   echo -e "\t-v or --verbose\t\t\t\t\t\tPrint verbose information."
   echo -e "\t-u or --undo\t\t\t\t\t\tReset any changes made in all repositories. WARNING: Your changes will be lost!"
   echo -e "\t-d or --develop\t\t\t\t\t\tWill checkout the develop branch in all repositories."
   echo -e "\t-m or --master\t\t\t\t\t\tWill checkout the master branch in all repositories."
   echo -e "\t-b <branch> or --branch <branch>\t\t\tWill checkout the <branch> branch in all repositories."
   echo -e "\t-p <project> or --project <project>\t\tWill set which project repositories to pull."
   echo -e "\t--all\t\t\t\t\t\t\tWill pull all repositories for all projects."
}

#
# Function for parsing script arguments
#
parse_args() {
   while [ ! -z "$1" ]; do
      param="$1"
      case ${param} in
         -h | --help)
            print_usage
            exit 0
            ;;
         -v | --verbose)
            VERBOSE=true
            ;;
         -u | --undo)
            UNDO=true
            ;;
         -d | --develop)
            if [ -n "${BRANCH}" ]; then
               log_error "Branch already specified"
               print_usage
               exit 1
            fi
            BRANCH="develop"
            ;;
         -m | --master)
            if [ -n "${BRANCH}" ]; then
               log_error "Branch already specified"
               print_usage
               exit 1
            fi
            BRANCH="master"
            ;;
         -b | --branch)
            shift
            BRANCH="$1"
            if [ -z "${BRANCH}" ]; then
               log_error "Branch not specified when using -b/--branch argument"
               print_usage
               exit 1
            fi
            ;;
         --all)
            if [ -n "${PROJECT}" ]; then
               log_error "Application already specified"
               print_usage
               exit 1
            fi
            PROJECT="_ALL_PROJECTS"
            ;;
         -p | --project)
            if [ -n "${PROJECT}" ]; then
               log_error "Application already specified"
               print_usage
               exit 1
            fi
            shift
            PROJECT="$1"
            if [ -z "${PROJECT}" ]; then
               log_error "Application not specified when using -p/--project argument"
               print_usage
               exit 1
            fi
            ;;
         *)
            log_error "Unknown parameter \"${param}\""
            print_usage
            exit 1
            ;;
      esac
      shift
   done
}

#
# Function for pulling one of the repos for an project
#
pull_repo() {
   repo="$1"
   verbose="$2"

   if [ -z "${repo}" ]; then
      log_error "Repository directory is blank"
      exit 1
   fi

   REPO_DIR="${WORKSPACE_DIR}/${repo}"

   if [ ! -d "${REPO_DIR}" ]; then
      log_warn "Repository directory ${REPO_DIR} does not exist"
      return
   fi

   cd "${REPO_DIR}"

   if [ ! git status > /dev/null 2>&1 ]; then
      log_warn "Directory ${REPO_DIR} is not a Git repository"
      return
   fi

   current_branch=$(git rev-parse --abbrev-ref HEAD)

   if [ "${UNDO}" = true ]; then
      log_info "Resetting changes for repository <${repo}> on branch <${current_branch}>"
      
      if [ "${VERBOSE}" = true ]; then
         git checkout -- .
      else
         git checkout -- . > /dev/null 2>&1
      fi
   fi

   if [ ! -z "${BRANCH}" ]; then

      log_info_tail "Checking out <${BRANCH}> for repository <${repo}>"

      if [ "${VERBOSE}" = true ]; then
         if git checkout "${BRANCH}"; then
            log_tail ": success!"
         else
            log_tail ": failed!"
         fi
      else
         if git checkout "${BRANCH}" > /dev/null 2>&1; then
            log_tail ": success!"
         else
            log_tail ": failed!"
         fi
      fi
   fi

   current_branch=$(git rev-parse --abbrev-ref HEAD)

   changes=""
   if [ ! -z "$(git status --untracked-files=no --porcelain)" ]; then
      changes=" (has uncommited changes)"
   fi

   log_info_tail "Pulling repository <${repo}> on branch <${current_branch}>${changes}"

   if [ "${VERBOSE}" = true ]; then
      if git pull; then
         log_tail ": success!"
      else
         log_tail ": failed!"
      fi
   else
      if git pull > /dev/null 2>&1; then
         log_tail ": success!"
      else
         log_tail ": failed!"
      fi
   fi
}

#
# Function for pulling all repos for a project
#
pull_repos() {
   repos=()

   # Select list of repos based on user input
   case "${PROJECT}" in

      "_ALL_PROJECTS")
      log_info "Pulling all repositories for all projects"
      repos=( ${GIT_REPOS[@]} )
      ;;

      *)
      log_info "Pulling repositories for project \"${PROJECT}\""
      for repo in "${GIT_REPOS[@]}"
      do
         if [[ "${repo}" =~ ^"${PROJECT}"\/.+$ ]]; then
            repos+=("${repo}")
         fi
      done
      ;;
   esac

   # Check if repo list is empty
   if [ ${#repos[@]} -eq 0 ]; then
      log_error "Repository list is empty"
      exit 1
   fi

   # Loop through list of repos and pull each
   for repo in "${repos[@]}"
   do
      pull_repo "${repo}"
   done

   log_info "Done!"
}

trap 'on_exit' EXIT

# Parse scipt arguments
parse_args "$@"

if [ -z "${PROJECT}" ]; then
   print_usage
   exit 1
fi

if [ -z "${GIT_REPOS}" ]; then
   log_error "Repository list is not defined"
   exit 1
fi

# Run functionality
pull_repos

exit 0
