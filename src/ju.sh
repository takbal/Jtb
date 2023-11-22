alias mkj="$HOME/.julia/environments/mkj/mkj.jl"

# copy the first workspace for mkj
export JU_WORKSPACE=${WORKSPACES[@]:0:1}

# automatically select and run julia in an environment, like "ju envname [params]"

ju()
{

  # this makes completion work for arguments
  if [[ $1 == "--help" ]]; then
    julia --help
    return
  fi

  if [[ "$#" == "0" ||  $1 == "." ]]; then
          projectdir=`julia --startup-file=no --project=@. -e "println(dirname(Base.active_project()))"`
  else
    if [ -d $HOME/.julia/environments/$1 ]; then
      projectdir=$HOME/.julia/environments/$1
    else
      projectdir=""
      for act_dir in ${WORKSPACES[@]}; do
        if [ -d $act_dir/$1 ]; then
          projectdir=$act_dir/$1
          break
        fi
      done
      if [[ -z "${projectdir}" ]]; then
        echo "cannot find specified environment"
        return 1
      fi
    fi
  fi

  if [ $# != "0" ]; then
    shift
  fi

        if [ -f ${projectdir}/JuliaSysimage.so ]; then
                julia --project=$projectdir --banner=no --color=yes -t auto,auto -O3 --sysimage ${projectdir}/JuliaSysimage.so $@
        else
                julia --project=$projectdir --banner=no --color=yes -t auto,auto -O3 $@
        fi
}

ju_shell=`ps -p $$ -o comm=`

# automatic env completion for the ju() call in zsh

if [[ $ju_shell == "zsh" ]]; then

  _ju() {
    local state

    _arguments \
      '1: :->julia_environment'\
      '*: :->other'

    # add more directories here if you need:
    envs_ls=`ls -1d $HOME/workspace/*/ $HOME/.julia/environments/*/`
    envs_array=("${(f)envs_ls}")
    envs=()
    for i in $envs_array; do envs+=`basename $i`; done

    case $state in
      (julia_environment) _arguments '1:environment:($envs)' ;;
      (other) _gnu_generic ;;
    esac
  }

  compdef _ju ju
  compdef _gnu_generic julia

fi
