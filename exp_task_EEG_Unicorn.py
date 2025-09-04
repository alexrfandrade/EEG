import os
import random
import pandas as pd
from datetime import datetime
from PIL import Image
from psychopy import visual, event, core
import socket

# === Global experiment parameters ===
nStandard = 108
nOddball = 27
stimDuration = 0.5  # seconds
ISI = 0.5  # inter-stimulus interval
stimSize = (600, 600)
responseKey = 'o'

# === Folder paths ===
oddFolder = 'oddballs'
stdFolder = 'standards'
resultsFolder = 'results'
os.makedirs(resultsFolder, exist_ok=True)

# === Global results list ===
results = []

# === UDP setup for Unicorn Recorder triggers ===
UDP_IP = "127.0.0.1"  # Unicorn IP
UDP_PORT = 1000       # port for triggers
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
endPoint = (UDP_IP, UDP_PORT)

# === Trigger options ===
send_per_trial = False  # True = triggers for each stimulus, False = only start/end

def send_trigger(trigger_value):
    """Send a trigger to Unicorn Recorder via UDP."""
    sock.sendto(str(trigger_value).encode(), endPoint)
    print(f"Trigger sent: {trigger_value}")

# === Check for ESC key ===
def check_for_exit():
    if 'escape' in event.getKeys():
        raise KeyboardInterrupt

# === Show instruction screen ===
def show_instructions(win):
    instructions = visual.TextStim(
        win,
        text="Press 'o' when you see a clear face.\n\nPress ENTER to continue.",
        color='white',
        height=30,
        wrapWidth=1000
    )
    instructions.draw()
    win.flip()
    while True:
        check_for_exit()
        if 'return' in event.waitKeys():
            core.wait(0.1)
            break

# === Load oddball image for a given block ===
def load_single_image(win, folder, block_num):
    target_suffix = f"{block_num}.png"
    for f in os.listdir(folder):
        if f.endswith(target_suffix):
            img_path = os.path.join(folder, f)
            pil_img = Image.open(img_path).convert('RGB')
            return visual.ImageStim(win, image=pil_img, size=stimSize, pos=(0, 0))
    raise FileNotFoundError(f"No image ending in {target_suffix} found in {folder}")

# === Save results ===
def save_results(results, suffix="final"):
    df = pd.DataFrame(results)
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    filename = f'results_oddball_{suffix}_{timestamp}.csv'
    filepath = os.path.join(resultsFolder, filename)
    df.to_csv(filepath, index=False)
    print(f"Results saved to: {filepath}")

# === Wait screen ===
def wait_screen(win, text="Preparing the experiment... Please wait."):
    wait_text = visual.TextStim(win, text=text, color='white', height=30)
    wait_text.draw()
    win.flip()

# === Main experiment loop ===
def run_experiment(n_blocks=1):
    global results
    win = visual.Window(fullscr=True, color=(0, 0, 0), units='pix')
    wait_screen(win)
    show_instructions(win)
    core.wait(0.5)

    # === Send start trigger ===
    send_trigger(1)

    globalClock = core.Clock()
    fixation = visual.TextStim(win, text='+', color='white', height=40, pos=(0, 0))

    for block_num in range(1, n_blocks + 1):
        print(f"\n--- Starting block {block_num} ---")
        wait_screen(win)
        core.wait(2)

        # Load standard images
        std_block_folder = os.path.join(stdFolder, f"scrambled_faces_{block_num}")
        std_images = []
        for f in sorted(os.listdir(std_block_folder)):
            if f.lower().endswith(('.png', '.jpg', '.jpeg')):
                pil_img = Image.open(os.path.join(std_block_folder, f)).convert('RGB')
                std_images.append(visual.ImageStim(win, image=pil_img, size=stimSize, pos=(0, 0)))
        if len(std_images) != nStandard:
            raise ValueError(f"Expected {nStandard} standard images in {std_block_folder}, found {len(std_images)}.")
        random.shuffle(std_images)
        oddStim = load_single_image(win, oddFolder, block_num)

        # Block start
        blockText = visual.TextStim(win, text=f"Block {block_num} / {n_blocks}\n\nPress ENTER to start.", color='white', height=30)
        blockText.draw()
        win.flip()
        while True:
            check_for_exit()
            if 'return' in event.getKeys():
                break

        # Trial sequence
        trialSequence = [True]*nOddball + [False]*nStandard
        random.shuffle(trialSequence)
        std_index = 0

        for trial_num, isOddball in enumerate(trialSequence, 1):
            check_for_exit()
            stim = oddStim if isOddball else std_images[std_index]
            if not isOddball:
                std_index += 1

            # Optional per-trial trigger
            if send_per_trial:
                send_trigger(1 if isOddball else 2)  # 1=oddball, 2=standard

            stim.draw()
            win.flip()
            tTarget = globalClock.getTime()

            responded, RT = False, None
            timer = core.Clock()
            while timer.getTime() < stimDuration:
                check_for_exit()
                for key, keyTime in event.getKeys(timeStamped=globalClock):
                    if key == responseKey:
                        RT = keyTime - tTarget
                        responded = True
            win.flip()

            # Inter-stimulus interval with fixation
            fixation.draw()
            win.flip()
            timer = core.Clock()
            while timer.getTime() < ISI:
                check_for_exit()

            results.append({
                'block': block_num,
                'trial': trial_num,
                'is_oddball': isOddball,
                'oddball_timing': tTarget,
                'response_time': RT,
                'responded': responded
            })

        save_results(results, suffix=f'block{block_num}')

    # === Send end trigger ===
    send_trigger(0)

    visual.TextStim(win, text='End of the test! Thank you :)', color='white').draw()
    win.flip()
    while True:
        check_for_exit()
        if 'return' in event.getKeys():
            break

    sock.close()
    win.close()
    return results

if __name__ == "__main__":
    try:
        results = run_experiment()
    except KeyboardInterrupt:
        print("\nExperiment interrupted by user.")
    except Exception as e:
        print(f"An error occurred: {e}")
    finally:
        if results:
            save_results(results, suffix="interrupted")
