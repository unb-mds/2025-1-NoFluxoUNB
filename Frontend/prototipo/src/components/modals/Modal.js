class Modal {
    constructor(content, options = {}) {
        this.content = content;
        this.options = {
            closeOnOutsideClick: true,
            showCloseButton: true,
            ...options
        };
        this.modal = null;
    }

    show() {
        this.modal = document.createElement('div');
        this.modal.className = 'modal';
        this.modal.innerHTML = `
            <div class="modal-content">
                ${this.options.showCloseButton ? `
                    <button class="close-button absolute top-4 right-4 text-gray-400 hover:text-white">
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                        </svg>
                    </button>
                ` : ''}
                ${this.content}
            </div>
        `;

        document.body.appendChild(this.modal);
        this.initializeEventListeners();
    }

    hide() {
        if (this.modal) {
            this.modal.remove();
            this.modal = null;
        }
    }

    initializeEventListeners() {
        if (this.options.closeOnOutsideClick) {
            this.modal.addEventListener('click', (e) => {
                if (e.target === this.modal) {
                    this.hide();
                }
            });
        }

        const closeButton = this.modal.querySelector('.close-button');
        if (closeButton) {
            closeButton.addEventListener('click', () => this.hide());
        }
    }

    updateContent(newContent) {
        if (this.modal) {
            const contentContainer = this.modal.querySelector('.modal-content');
            if (contentContainer) {
                contentContainer.innerHTML = `
                    ${this.options.showCloseButton ? `
                        <button class="close-button absolute top-4 right-4 text-gray-400 hover:text-white">
                            <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                            </svg>
                        </button>
                    ` : ''}
                    ${newContent}
                `;
                this.initializeEventListeners();
            }
        }
    }
}

export default Modal; 