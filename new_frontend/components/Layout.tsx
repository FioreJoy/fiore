import React, { useState, Fragment } from 'react';
import { NavLink, Link, useNavigate } from 'react-router-dom';
import { useAuth } from '../hooks/useAuth';
import { HomeIcon, UsersIcon, BellIcon, LogoutIcon, UserCircleIcon, CalendarIcon, ChatBubbleIcon } from './icons';
import { Menu, Transition } from '@headlessui/react';

const SideNav: React.FC = () => {
  const { user } = useAuth();
  const navItems = [
    { name: 'Home', href: '/', icon: HomeIcon },
    { name: 'Communities', href: '/communities', icon: UsersIcon }, // Placeholder link
    { name: 'Chat', href: '/chat', icon: ChatBubbleIcon },
    { name: 'Events', href: '/events', icon: CalendarIcon },
    { name: 'Notifications', href: '/notifications', icon: BellIcon }, // Placeholder link
    { name: 'Profile', href: `/profile/${user?.id}`, icon: UserCircleIcon },
  ];

  const activeLink = "bg-surface text-primary";
  const inactiveLink = "hover:bg-surface text-text-secondary";

  return (
    <nav className="flex flex-col p-4 space-y-2">
      <div className="text-2xl font-bold text-primary mb-6">Fiore</div>
      {navItems.map((item) => (
        <NavLink
          key={item.name}
          to={item.href}
          end={item.href === '/'}
          className={({ isActive }) =>
            `flex items-center p-3 rounded-lg transition-colors duration-200 ${isActive ? activeLink : inactiveLink}`
          }
        >
          <item.icon className="h-6 w-6 mr-4" />
          <span className="font-medium">{item.name}</span>
        </NavLink>
      ))}
    </nav>
  );
};


const Header: React.FC = () => {
    const { user, logout } = useAuth();
    const navigate = useNavigate();

    const handleLogout = () => {
        logout();
        navigate('/login');
    };

    return (
        <header className="flex items-center justify-between p-4 bg-surface border-b border-gray-700">
            {/* Search Bar - Future implementation */}
            <div className="w-1/3">
                 <input type="search" placeholder="Search Fiore..." className="bg-background w-full px-4 py-2 rounded-full focus:outline-none focus:ring-2 focus:ring-primary" />
            </div>

            {/* User Menu */}
            <div className="relative">
                <Menu as="div" className="relative inline-block text-left">
                    <div>
                        <Menu.Button className="flex items-center rounded-full bg-background text-sm focus:outline-none focus:ring-2 focus:ring-primary focus:ring-offset-2 focus:ring-offset-background">
                            <span className="sr-only">Open user menu</span>
                            <img
                                className="h-10 w-10 rounded-full object-cover"
                                src={user?.image_url || `https://picsum.photos/seed/${user?.id}/100/100`}
                                alt={user?.name}
                            />
                        </Menu.Button>
                    </div>
                    <Transition
                        as={Fragment}
                        enter="transition ease-out duration-100"
                        enterFrom="transform opacity-0 scale-95"
                        enterTo="transform opacity-100 scale-100"
                        leave="transition ease-in duration-75"
                        leaveFrom="transform opacity-100 scale-100"
                        leaveTo="transform opacity-0 scale-95"
                    >
                        <Menu.Items className="absolute right-0 mt-2 w-56 origin-top-right divide-y divide-gray-600 rounded-md bg-surface shadow-lg ring-1 ring-black ring-opacity-5 focus:outline-none">
                            <div className="px-1 py-1 ">
                                <div className="px-4 py-3">
                                    <p className="text-sm text-text-primary">Signed in as</p>
                                    <p className="truncate text-sm font-medium text-text-primary">{user?.username}</p>
                                </div>
                                <Menu.Item>
                                    {({ active }) => (
                                        <Link to={`/profile/${user?.id}`} className={`${active ? 'bg-primary text-white' : 'text-text-primary'} group flex w-full items-center rounded-md px-2 py-2 text-sm`}>
                                            Your Profile
                                        </Link>
                                    )}
                                </Menu.Item>
                            </div>
                            <div className="px-1 py-1">
                                <Menu.Item>
                                    {({ active }) => (
                                        <button onClick={handleLogout} className={`${active ? 'bg-accent text-white' : 'text-text-primary'} group flex w-full items-center rounded-md px-2 py-2 text-sm`}>
                                            <LogoutIcon className="mr-2 h-5 w-5" />
                                            Logout
                                        </button>
                                    )}
                                </Menu.Item>
                            </div>
                        </Menu.Items>
                    </Transition>
                </Menu>
            </div>
        </header>
    );
};


const Layout: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  return (
    <div className="min-h-screen flex">
      {/* Left Sidebar */}
      <aside className="w-64 bg-background border-r border-gray-800 hidden md:block flex-shrink-0">
        <div className="sticky top-0">
          <SideNav />
        </div>
      </aside>

      {/* Main Content Area */}
      <main className="flex-1 flex flex-col">
        <div className="sticky top-0 z-10">
            <Header />
        </div>
        <div className="flex-1 overflow-y-auto p-4 md:p-6">
            <div className="max-w-7xl mx-auto w-full">
                {children}
            </div>
        </div>
      </main>
    </div>
  );
};

export default Layout;