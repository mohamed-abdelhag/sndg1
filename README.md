# Sandoog

Sandoog is a group savings management application built with SvelteKit. It allows users to create groups, manage members, set savings goals, track contributions, and handle withdrawal requests. The application supports two types of savings groups to accommodate different saving styles.

## Features

### User Authentication
* User Login
* User Sign Up

### Group Management
* Create groups with an administrator
* Two types of groups:
    * **Standard Savings Groups:** Members contribute monthly towards a goal with withdrawal options
    * **Lump Sum Lottery Groups:** Members contribute monthly, and one randomly selected member receives the entire pool each month until all members have won once
* Add and remove group members
* Set monthly savings goals (for Standard Savings Groups)

### Savings Tracking
* Users can mark their monthly contributions
* Track overall group savings progress
* Monitor contribution deficits (shows how much each user is behind, e.g., "X dirhams behind")
* Monthly contribution status tracking

### Standard Savings Groups Features
* Track progress towards group savings goal
* Members can request withdrawals from the pool
* Administrators can approve/reject withdrawal requests
* Set payback rates (interest-free) for withdrawals
* Payback amounts are added to monthly dues

### Lump Sum Lottery Groups Features
* Equal monthly contributions from all members
* Automated random selection of winner at month-end
* Fair distribution system (each member wins exactly once)
* Tracking of previous winners and remaining eligible members
* Contribution deficit tracking affects eligibility

## Technologies Used

* SvelteKit
* Prisma (Database ORM)
* PostgreSQL (Database)
* TypeScript
* Lucia (Authentication)
* TailwindCSS (Styling)

## Getting Started

```bash
# Clone the repository
git clone [repository-url]

# Install dependencies
npm install

# Set up environment variables
cp .env.example .env

# Start development server
npm run dev
```

## Environment Setup

Create a `.env` file with the following variables:

```env
DATABASE_URL="postgresql://..."
AUTH_SECRET="your-secret-key"
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
