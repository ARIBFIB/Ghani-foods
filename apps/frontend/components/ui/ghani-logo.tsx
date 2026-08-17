export function GhaniLogo({ className = "size-5" }: { className?: string }) {
  return (
    <svg
      viewBox="0 0 24 24"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      className={className}
      aria-hidden="true"
    >
      <path
        d="M12 2C12 2 9.5 4.5 9.5 7.5C9.5 9.15685 10.6193 10 12 10C13.3807 10 14.5 9.15685 14.5 7.5C14.5 4.5 12 2 12 2Z"
        fill="currentColor"
      />
      <path
        d="M7.5 6.5C7.5 6.5 5.5 8.5 5.5 11C5.5 12.3807 6.5 13 7.5 13C8.5 13 9.5 12.3807 9.5 11C9.5 8.5 7.5 6.5 7.5 6.5Z"
        fill="currentColor"
      />
      <path
        d="M16.5 6.5C16.5 6.5 14.5 8.5 14.5 11C14.5 12.3807 15.5 13 16.5 13C17.5 13 18.5 12.3807 18.5 11C18.5 8.5 16.5 6.5 16.5 6.5Z"
        fill="currentColor"
      />
      <path
        d="M12 9C12 9 9.5 11.5 9.5 14.5C9.5 16.1569 10.6193 17 12 17C13.3807 17 14.5 16.1569 14.5 14.5C14.5 11.5 12 9 12 9Z"
        fill="currentColor"
      />
      <path
        d="M12 16V22"
        stroke="currentColor"
        strokeWidth="1.5"
        strokeLinecap="round"
      />
    </svg>
  );
}

export default GhaniLogo;