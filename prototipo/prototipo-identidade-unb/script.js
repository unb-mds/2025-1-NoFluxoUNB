const tabButtons = document.querySelectorAll(".tab-button");
const screens = document.querySelectorAll(".screen");

function showScreen(screenId) {
    screens.forEach((screen) => {
        screen.classList.toggle("is-active", screen.id === `screen-${screenId}`);
    });

    tabButtons.forEach((button) => {
        button.classList.toggle("is-active", button.dataset.screen === screenId);
    });
}

tabButtons.forEach((button) => {
    button.addEventListener("click", () => {
        showScreen(button.dataset.screen);
    });
});
