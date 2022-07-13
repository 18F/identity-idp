import { Icon, IconListContent, IconListIcon, IconListTitle } from '@18f/identity-components';
import type { ReactNode } from 'react';
import type { DesignSystemIcon } from '../icon';

interface IconListItemProps {
  children?: ReactNode;

  icon: DesignSystemIcon;

  title: string;
}

function IconListItem({ children, icon, title }: IconListItemProps) {
  const classes = 'usa-icon-list__item';

  return (
    <li className={classes}>
      <IconListIcon className="text-primary-dark">
        <Icon icon={icon} />
      </IconListIcon>
      <IconListContent>
        <IconListTitle className="font-sans-md padding-top-0">{title}</IconListTitle>
        {children}
      </IconListContent>
    </li>
  );
}

export default IconListItem;
