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
  elif [ -d $HOME/.julia/environments/$1 ]; then
    projectdir=$HOME/.julia/environments/$1
  elif [ -d $HOME/workspace/$1 ]; then
    projectdir=$HOME/workspace/$1
  else
    echo "cannot find specified environment"
    return 1
  fi

  if [ $# != "0" ]; then
    shift
  fi

        if [ -f ${projectdir}/JuliaSysimage.so ]; then
                julia --project=$projectdir --banner=no --color=yes -t auto -O3 --sysimage ${projectdir}/JuliaSysimage.so $@
        else
                julia --project=$projectdir --banner=no --color=yes -t auto -O3 $@
        fi
}

# automatic env completion for the ju() call in zsh (cut this below for bash)

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
