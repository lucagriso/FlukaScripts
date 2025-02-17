#!/bin/bash #commento casuale senza senso

export FLUPRO=/mnt/c/Users/Mio/Desktop/Luca/FLUKA_INFN/fluka
export FLUFOR=gfortran

# Inizializza variabili a stringa vuota (così sappiamo se sono state assegnate)
file_input=""
num_files=1
in_parallelo=1
num_cicli=1
checkpoint_log="checkpoint.txt" #per salvare lo storico delle simulazioni avvenute


while [[ $# -gt 0 ]]; do 
    case "$1" in
        -i|--input)
            file_input="$2"
            shift 2
            ;;
        -n|--num-files)
            num_files="$2"
            shift 2
            ;;
        -p|--parallel)
            in_parallelo="$2"
            shift 2
            ;;
        -m|--multiplicity)
            num_cicli="$2"
            shift 2
            ;;
        --reset)
            echo "Reset del checkpoint..."
            rm -f "$checkpoint_log"
            touch "$checkpoint_log"
            shift
            ;;
        --clean)
            clean_mode=true
            shift
            ;;
        -h|--help)
            help_mode=true
            shift
            ;;
        *)
            echo "!!!! Opzione non riconosciuta: $1"
            echo "  Uso corretto:"
            echo "   ./FlukaAutoRunOpt.sh -i <input_file_name> -n <num_files_to_generate|def=1> -p <to_run_in_parallel|def=1> -m <cycles_number|def=1>"
            exit 1
            ;;
    esac
done

# Se è stata richiesto aiuto, diamo aiuto
if [ "$help_mode" = true ]; then
    echo "## Script per eseguire in automatico numerose simulazioni FLUKA ##"
    echo ""
    echo "Sintassi:"
    echo "  ./FlukaAutoRunOpt.sh [opzioni]"
    echo ""
    echo "Opzioni:"
    echo "  -i, --input <file_input>        Specifica il file di input originale. (OBBLIGATORIO)"
    echo "  -n, --num-files <numero>        Numero di file di input diversi da generare (default: 1)"
    echo "  -p, --parallel <numero>         Numero massimo di simulazioni in parallelo da eseguire (default: 1)"
    echo "  -m, --multiplicity <numero>     Numero di cicli per ogni simulazione FLUKA (default: 1)"
    echo "  --reset                         Resetta il file di checkpoint/log (per ricominciare da zero tutte le simulazioni)"
    echo "  --clean                         Pulisce la cartella rimuovendo i file di simulazione (.out .log -fort ran) e gli input creati"
    echo "  -h, --help                      Mostra questo messaggio di aiuto e termina lo script (NON SERVE L'OPZIONE -i)" 
    echo ""
    echo "Esempi:"
    echo "  ./FlukaAutoRunOpt.sh -i Liglass_auto.inp -n 10 -p 3 -m 5"
    echo "  ./FlukaAutoRunOpt.sh -i Liglass_auto.inp --reset"
    echo "  ./FlukaAutoRunOpt.sh -i Liglass_auto.inp --clean"
    echo "  ./FlukaAutoRunOpt.sh --help"
    echo ""
    echo "Descrizione:"
    echo "  Questo script esegue simulazioni FLUKA partendo da un file di input originale ed eventuale eseguibile già preparati."
    echo "  È possibile specificare il numero di nuovi input da generare, come se fosse l'opzione 'spawn di flair"
    echo "  il numero massimo di simulazioni parallele, e il numero di cicli per ogni simulazione." 
    echo "  L'opzione --clean elimina i nuovi file input generati, i file di simulazione e i file di output"
    echo "  dalle simulazioni precedenti. L'opzione --reset ripristina il file log/checkpoint."
    echo ""
    echo "ATTENZIONE ATTENZIONE"
    echo "Il comando a riga circa 148 è da cambiare mettendo la destinazione del file 'rfluka' nel proprio PC e l'eventuale eseguibile con l'opzione '-e'"
    exit 0
fi

#Controllo che tutte le opzioni siano state inserite
if [[ -z "$file_input" ]]; then
    echo "!!!! Errore: Devi specificare almeno il nome del file input originale!"
    echo "   Uso corretto:"
    echo "   ./FlukaAutoRunOpt.sh -i <input_file_name> -n <num_files_to_generate|def=1> -p <to_run_in_parallel|def=1> -m <cycles_number|def=1>"
    exit 1
fi

# Controlla se il file di input originale esiste
if [[ ! -f "$file_input" ]]; then
    echo "!!!! Errore: Il file di input \"$file_input\" non esiste!"
    exit 1
fi

# Se è stata richiesta la pulizia, eliminare i file e terminare lo script
if [ "$clean_mode" = true ]; then
    base_name="${file_input%.inp}"  # Rimuove l'estensione dal nome file
    echo "# Pulizia della cartella..."
    rm -f "${base_name}"_*_.inp "${base_name}"_*_[0-9]*.inp "${base_name}"_*_-echo.inp "${base_name}"_*_[0-9]*_*.txt *.out *.err *.log nohup.out ran* *.[0-9]*
    echo "OK! Pulizia completata!"
    exit 0
fi

pids=()  # Array per salvare i PID
sim_names=()  # Array per registrare i nomi delle simu che stanno andando in parallelo associate ai PID
simulazioni=() #Array per salvare tutti i nomi degli input

# Genera i file di input basandosi sul nome originale
base_name="${file_input%.inp}"  # Rimuove l'estensione ".inp"

for j in $(seq 1 "$num_files"); do
    seed=$(( RANDOM * RANDOM % 900000000 ))
    file_output="${base_name}_${j}_.inp"
    sed -E "s/(RANDOMIZ[[:space:]]+1\.)/\1    $seed./" "$file_input" > "$file_output"
    simulazioni+=("$file_output")
    echo "Creato: $file_output con seed $seed"
done

if [ "$1" == "--reset" ]; then
    echo "Reset del checkpoint..."
    rm -f "$checkpoint_log"
    touch "$checkpoint_log"
fi

i=1 #contatore
#Inizio a simulare a batch di "in_parallelo"
for sim in "${simulazioni[@]}"; do

    # Controlla se la simulazione è già stata completata
    if grep -q "$sim" "$checkpoint_log"; then
        echo "Simulazione $sim già completata, salto..."
        ((i++))
        continue
    fi

    echo "Avvio simulazione $i: $sim"

    ###############################################ATTENZIONE COMANDO FLUKA ATTENZIONE#################################################
    #Il seguente comando è da cambiare mettendo la destinazione di 'rfluka' nel proprio PC e l'eventuale eseguibile con l'opzione '-e'#
    /usr/bin/nohup /mnt/c/Users/Mio/Desktop/Luca/FLUKA_INFN/fluka/flutil/rfluka -e /mnt/c/Users/Mio/Desktop/Luca/FLUKA_INFN/inputs/LiGLASS/LiAutomat/exeAuto -M "$num_cicli" "$sim" &
    ###################################################################################################################################

    pid=$!  # Salva il PID del processo avviato
    pids+=("$pid")  # Aggiunge il PID all'array
    sim_names+=("$sim")  # Tiene traccia del file di input corrispondente

    if [ ${#pids[@]} -ge $in_parallelo ]; then
        echo "Aspetto che finiscano ${#pids[@]} simulazioni..."
        for ((j=0; j<${#pids[@]}; j++)); do
            wait "${pids[j]}"
            exit_status=$?

            if [ $exit_status -eq 0 ]; then
                echo "${sim_names[j]}" >> "$checkpoint_log"  # Segna solo se è riuscita
            else
                echo "Errore nella simulazione ${sim_names[j]} (PID ${pids[j]}), verrà rieseguita." >&2
            fi
        done
        pids=()  # Svuota l'array per il prossimo batch
        sim_names=()  # Svuota anche l'array dei nomi delle simulazioni
    fi

    ((i++))  # Incrementa il numero della simulazione
done

# Attendere eventuali processi rimanenti
if [ ${#pids[@]} -gt 0 ]; then
    echo "Attesa finale..."
    for ((j=0; j<${#pids[@]}; j++)); do
        wait "${pids[j]}"
        exit_status=$?

        if [ $exit_status -eq 0 ]; then
            echo "${sim_names[j]}" >> "$checkpoint_log"  # Segna solo se è riuscita
        else
            echo "Errore nella simulazione ${sim_names[j]} (PID ${pids[j]}), verrà rieseguita." >&2
        fi
    done
fi

echo "Tutti le simulazioni sono state completate."

