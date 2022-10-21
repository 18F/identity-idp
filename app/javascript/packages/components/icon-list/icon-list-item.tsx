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
      <IconListIcon>
        <Icon icon={icon} />
      </IconListIcon>
      <IconListContent>
        <IconListTitle>{title}</IconListTitle>
        {children}
      </IconListContent>
    </li>
  );
}

export default IconListItem;
